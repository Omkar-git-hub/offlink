// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../protocol/offlink_message_type.dart';
import '../protocol/offlink_packet.dart';
import '../protocol/packet_transport.dart';
import '../queue/store_and_forward_manager.dart';
import 'routing_table.dart';
import 'seen_message_cache.dart';

class MeshPacketRouter implements PacketTransport {
  MeshPacketRouter({
    required PacketTransport transport,
    required String Function() getLocalNodeId,
    SeenMessageCache? seenCache,
    RoutingTable? routingTable,
    List<String> Function()? getConnectedPeerIds,
    this.defaultTtl = 4,
    StoreAndForwardManager? storeAndForwardManager,
  }) : _transport = transport,
       _getLocalNodeId = getLocalNodeId,
       _seenCache = seenCache ?? SeenMessageCache(),
       _routingTable = routingTable ?? RoutingTable(),
       _getConnectedPeerIds = getConnectedPeerIds {
    this.storeAndForwardManager = storeAndForwardManager;
    _transportSubscription = _transport.incomingPackets.listen(
      _handleIncomingPacket,
    );
  }

  final PacketTransport _transport;
  final String Function() _getLocalNodeId;
  final SeenMessageCache _seenCache;
  final RoutingTable _routingTable;
  final List<String> Function()? _getConnectedPeerIds;
  final int defaultTtl;
  StoreAndForwardManager? storeAndForwardManager;

  final StreamController<OfflinkPacket> _inboundPackets =
      StreamController<OfflinkPacket>.broadcast();
  final StreamController<OfflinkPacket> _forwardedPackets =
      StreamController<OfflinkPacket>.broadcast();
  final StreamController<OfflinkPacket> _droppedPackets =
      StreamController<OfflinkPacket>.broadcast();

  StreamSubscription<OfflinkPacket>? _transportSubscription;

  @override
  Stream<OfflinkPacket> get incomingPackets => _inboundPackets.stream;

  Stream<OfflinkPacket> get forwardedPackets => _forwardedPackets.stream;

  Stream<OfflinkPacket> get droppedPackets => _droppedPackets.stream;

  RoutingTable get routingTable => _routingTable;

  SeenMessageCache get seenCache => _seenCache;

  @override
  List<String> get connectedPeerIds {
    if (_getConnectedPeerIds != null) {
      return _getConnectedPeerIds();
    }
    return _transport.connectedPeerIds;
  }

  void addDirectNeighbor(String peerId) {
    _routingTable.updateRoute(
      destinationNodeId: peerId,
      nextHopPeerId: peerId,
      hopCount: 1,
    );
    storeAndForwardManager?.onPeerOrRouteAvailable(peerId);
  }

  void removePeer(String peerId) {
    _routingTable.removeRoutesForPeer(peerId);
  }

  Future<void> onPacketReceived(
    OfflinkPacket packet, {
    String? fromPeerId,
  }) async {
    await _processIncomingPacket(packet, fromPeerId: fromPeerId);
  }

  Future<void> _handleIncomingPacket(OfflinkPacket packet) async {
    await _processIncomingPacket(packet);
  }

  Future<void> _processIncomingPacket(
    OfflinkPacket packet, {
    String? fromPeerId,
  }) async {
    // 1. Deduplication check: drop if already seen to prevent routing loops.
    if (!_seenCache.markIfUnseen(packet.messageId)) {
      _droppedPackets.add(packet);
      return;
    }

    final localNodeId = _getLocalNodeId();

    // 2. Route learning: record path back to sender if valid.
    if (packet.senderNodeId.isNotEmpty && packet.senderNodeId != localNodeId) {
      final hops = defaultTtl >= packet.ttl ? (defaultTtl - packet.ttl + 1) : 1;
      final nextHop =
          fromPeerId ??
          (connectedPeerIds.contains(packet.senderNodeId)
              ? packet.senderNodeId
              : (connectedPeerIds.length == 1
                    ? connectedPeerIds.first
                    : packet.senderNodeId));

      _routingTable.updateRoute(
        destinationNodeId: packet.senderNodeId,
        nextHopPeerId: nextHop,
        hopCount: hops,
      );
    }

    // 3. Destination evaluation:
    if (packet.messageType == OfflinkMessageType.acknowledgement) {
      await storeAndForwardManager?.onAckReceived(packet.payload);
    }

    final isForLocal =
        packet.recipientNodeId == localNodeId || packet.recipientNodeId == '*';

    if (isForLocal) {
      _inboundPackets.add(packet);

      // If it's a broadcast packet with remaining TTL, also forward it.
      if (packet.recipientNodeId == '*' && packet.ttl > 1) {
        await _forwardMeshPacket(packet, fromPeerId: fromPeerId);
      }
      return;
    }

    // 4. Relay forwarding: this node is an intermediate relay.
    if (packet.ttl <= 1) {
      // TTL expired, drop packet to prevent infinite circulation.
      _droppedPackets.add(packet);
      return;
    }

    await _forwardMeshPacket(packet, fromPeerId: fromPeerId);
  }

  Future<void> _forwardMeshPacket(
    OfflinkPacket packet, {
    String? fromPeerId,
  }) async {
    final forwarded = packet.copyWith(ttl: packet.ttl - 1);
    _forwardedPackets.add(forwarded);

    // Determine target peer:
    final knownRoute = _routingTable.getRoute(forwarded.recipientNodeId);
    final activeNeighbors = connectedPeerIds;

    var deliveredOrFlooded = false;
    if (knownRoute != null &&
        activeNeighbors.contains(knownRoute.nextHopPeerId)) {
      // Forward directly to next hop
      try {
        await _transport.sendPacket(
          peerId: knownRoute.nextHopPeerId,
          packet: forwarded,
        );
        deliveredOrFlooded = true;
      } catch (_) {
        // Fallback to flood if direct link fails
        deliveredOrFlooded = await _floodPacket(
          forwarded,
          excludePeerId: fromPeerId ?? knownRoute.nextHopPeerId,
        );
      }
    } else {
      // Destination next hop unknown, flood to active neighbors.
      // Exclude reverse path next hop if known or fromPeerId.
      final reverseRoute = _routingTable.getRoute(forwarded.senderNodeId);
      final excludePeer =
          fromPeerId ?? reverseRoute?.nextHopPeerId ?? forwarded.senderNodeId;
      deliveredOrFlooded = await _floodPacket(
        forwarded,
        excludePeerId: excludePeer,
      );
    }

    // If packet could not be immediately forwarded to any active peer,
    // store for forward when a viable route/neighbor appears.
    if (!deliveredOrFlooded && storeAndForwardManager != null) {
      await storeAndForwardManager!.enqueueInTransitPacket(forwarded);
    }
  }

  Future<bool> _floodPacket(
    OfflinkPacket packet, {
    String? excludePeerId,
  }) async {
    final neighbors = connectedPeerIds;

    if (neighbors.isEmpty) {
      // If neighbors list is empty, send via default transport channel
      try {
        await _transport.sendPacket(
          peerId: packet.recipientNodeId,
          packet: packet,
        );
        return true;
      } catch (_) {
        return false;
      }
    }

    var sentToAny = false;
    for (final peerId in neighbors) {
      if (peerId == excludePeerId || peerId == packet.senderNodeId) {
        continue;
      }
      try {
        await _transport.sendPacket(peerId: peerId, packet: packet);
        sentToAny = true;
      } catch (_) {
        // Continue flooding to other peers even if one link fails.
      }
    }
    return sentToAny;
  }

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    // Record our own packet ID in seen cache to prevent loopback processing.
    _seenCache.markSeen(packet.messageId);

    final activeNeighbors = connectedPeerIds;

    // 1. If explicit peerId is connected, send directly.
    if (activeNeighbors.contains(peerId)) {
      await _transport.sendPacket(peerId: peerId, packet: packet);
      return;
    }

    // 2. If destination route is known and connected, send to next hop.
    final route = _routingTable.getRoute(packet.recipientNodeId);
    if (route != null && activeNeighbors.contains(route.nextHopPeerId)) {
      await _transport.sendPacket(peerId: route.nextHopPeerId, packet: packet);
      return;
    }

    // 3. Otherwise, flood to all connected peers.
    final sent = await _floodPacket(packet);
    if (!sent && storeAndForwardManager != null) {
      await storeAndForwardManager!.enqueueInTransitPacket(packet);
    }
  }

  void dispose() {
    _transportSubscription?.cancel();
    _transportSubscription = null;
    _inboundPackets.close();
    _forwardedPackets.close();
    _droppedPackets.close();
  }
}
