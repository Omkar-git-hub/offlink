// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import '../mesh/routing_table.dart';
import '../protocol/offlink_packet.dart';
import '../protocol/packet_transport.dart';
import 'queued_packet.dart';
import 'store_and_forward_repository.dart';

/// Manager for store-and-forward delay-tolerant mesh networking.
/// Enqueues in-transit packets that cannot immediately be delivered,
/// and opportunisticly forwards them when matching peers or routes become available.
class StoreAndForwardManager {
  StoreAndForwardManager({
    required StoreAndForwardRepository repository,
    required PacketTransport transport,
    required RoutingTable routingTable,
    required String Function() getLocalNodeId,
    required List<String> Function() getConnectedPeerIds,
    this.checkInterval = const Duration(seconds: 15),
    this.maxPacketAge = const Duration(hours: 24),
    this.maxRetries = 5,
    this.maxQueueSize = 200,
    this.initialBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 5),
    Random? random,
  }) : _repository = repository,
       _transport = transport,
       _routingTable = routingTable,
       _getLocalNodeId = getLocalNodeId,
       _getConnectedPeerIds = getConnectedPeerIds,
       _random = random ?? Random();

  final StoreAndForwardRepository _repository;
  final PacketTransport _transport;
  final RoutingTable _routingTable;
  final String Function() _getLocalNodeId;
  final List<String> Function() _getConnectedPeerIds;

  final Duration checkInterval;
  final Duration maxPacketAge;
  final int maxRetries;
  final int maxQueueSize;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final Random _random;

  Timer? _periodicTimer;
  bool _isProcessing = false;

  void start() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(checkInterval, (_) {
      processStoreAndForward();
    });
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Determines if a packet is eligible for store-and-forward and enqueues it.
  /// Relay nodes store the encrypted ciphertext as-is without decrypting.
  Future<bool> enqueueInTransitPacket(OfflinkPacket packet) async {
    final localNodeId = _getLocalNodeId();

    // 1. Packets for the local node or broadcasts are not store-and-forwarded by relays
    if (packet.recipientNodeId == localNodeId ||
        packet.recipientNodeId == '*' ||
        packet.senderNodeId == localNodeId) {
      return false;
    }

    // 2. Packets with TTL <= 1 cannot be forwarded further
    if (packet.ttl <= 1) {
      return false;
    }

    // 3. Expiration check
    final now = DateTime.now().toUtc();
    if (now.difference(packet.timestamp) > maxPacketAge) {
      return false;
    }

    // 4. Enforce queue storage limit before enqueuing
    final currentSize = await _repository.getQueueSize();
    if (currentSize >= maxQueueSize) {
      await _repository.pruneExpired(
        maxAge: maxPacketAge,
        maxQueueSize: maxQueueSize,
      );
    }

    final queuedPacket = QueuedPacket.fromPacket(
      packet,
      createdAt: now,
      nextAttemptAt: now,
      status: QueuedPacketStatus.pending,
    );

    await _repository.enqueuePacket(queuedPacket);
    return true;
  }

  /// Removes a stored packet when an ACK is observed on the mesh.
  Future<void> onAckReceived(String ackMessageId) async {
    await _repository.removePacket(ackMessageId);
  }

  /// Triggered opportunistically when a peer connects or a new route is learned.
  Future<int> onPeerOrRouteAvailable(String peerId) async {
    return await flushEligiblePackets(targetPeerId: peerId);
  }

  /// Flushes eligible packets to available next-hops or connected peers.
  Future<int> flushEligiblePackets({String? targetPeerId}) async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    var forwardedCount = 0;
    try {
      final activeNeighbors = _getConnectedPeerIds();
      if (activeNeighbors.isEmpty) return 0;

      final pending = await _repository.getPendingPackets(limit: maxQueueSize);
      final now = DateTime.now().toUtc();

      for (final queued in pending) {
        // Skip if not yet due for next retry
        if (queued.nextAttemptAt.isAfter(now)) {
          continue;
        }

        // Check packet TTL
        if (queued.ttl <= 1) {
          await _repository.updatePacketStatus(
            queued.id,
            QueuedPacketStatus.expired,
          );
          continue;
        }

        // Determine destination next hop
        String? nextHop;
        if (targetPeerId != null) {
          if (queued.recipientNodeId == targetPeerId) {
            nextHop = targetPeerId;
          } else {
            final route = _routingTable.getRoute(queued.recipientNodeId);
            if (route != null && route.nextHopPeerId == targetPeerId) {
              nextHop = targetPeerId;
            }
          }
        } else {
          if (activeNeighbors.contains(queued.recipientNodeId)) {
            nextHop = queued.recipientNodeId;
          } else {
            final route = _routingTable.getRoute(queued.recipientNodeId);
            if (route != null &&
                activeNeighbors.contains(route.nextHopPeerId)) {
              nextHop = route.nextHopPeerId;
            }
          }
        }

        // If target next-hop was found:
        if (nextHop != null) {
          // Decrement TTL by 1 before transmission
          final packetToSend = queued.toPacket().copyWith(ttl: queued.ttl - 1);
          try {
            await _transport.sendPacket(peerId: nextHop, packet: packetToSend);
            forwardedCount++;

            // If forwarded directly to recipient, we can mark forwarded or remove upon ACK
            await _repository.updatePacketStatus(
              queued.id,
              QueuedPacketStatus.forwarded,
              ttl: queued.ttl - 1,
            );
          } catch (_) {
            // Forward attempt failed: increment retry count with exponential backoff & jitter
            final nextRetry = queued.retryCount + 1;
            if (nextRetry >= maxRetries) {
              await _repository.updatePacketStatus(
                queued.id,
                QueuedPacketStatus.failed,
              );
            } else {
              final delay = _calculateBackoffWithJitter(nextRetry);
              await _repository.updatePacketStatus(
                queued.id,
                QueuedPacketStatus.pending,
                retryCount: nextRetry,
                nextAttemptAt: now.add(delay),
              );
            }
          }
        }
      }
    } finally {
      _isProcessing = false;
    }

    return forwardedCount;
  }

  /// Periodic maintenance: prunes expired records and flushes ready packets.
  Future<void> processStoreAndForward() async {
    await _repository.pruneExpired(
      maxAge: maxPacketAge,
      maxQueueSize: maxQueueSize,
    );
    await flushEligiblePackets();
  }

  Duration _calculateBackoffWithJitter(int attempt) {
    // Exponential backoff: initialBackoff * 2^(attempt - 1)
    final expMs = initialBackoff.inMilliseconds * pow(2, attempt - 1);
    final cappedMs = min(
      expMs.toDouble(),
      maxBackoff.inMilliseconds.toDouble(),
    );
    // Jitter: +/- 20%
    final jitterFactor = 0.8 + (_random.nextDouble() * 0.4);
    final totalMs = (cappedMs * jitterFactor).toInt();
    return Duration(milliseconds: totalMs);
  }

  void dispose() {
    stop();
  }
}
