import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

class _FakeTransport implements PacketTransport {
  final StreamController<OfflinkPacket> _controller =
      StreamController<OfflinkPacket>.broadcast();
  final List<({String peerId, OfflinkPacket packet})> sent = [];
  List<String> connectedPeers = [];

  @override
  Stream<OfflinkPacket> get incomingPackets => _controller.stream;

  @override
  List<String> get connectedPeerIds => connectedPeers;

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    sent.add((peerId: peerId, packet: packet));
  }

  void emit(OfflinkPacket packet) {
    _controller.add(packet);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('MeshPacketRouter', () {
    late _FakeTransport transport;
    late MeshPacketRouter router;
    const localNodeId = 'node-bob';

    setUp(() {
      transport = _FakeTransport();
      router = MeshPacketRouter(
        transport: transport,
        getLocalNodeId: () => localNodeId,
      );
    });

    tearDown(() {
      router.dispose();
      transport.dispose();
    });

    test(
      'delivers packet destined for local node to incomingPackets stream',
      () async {
        final received = <OfflinkPacket>[];
        final sub = router.incomingPackets.listen(received.add);

        final packet = OfflinkPacket(
          messageId: 'msg-local-1',
          senderNodeId: 'node-alice',
          recipientNodeId: localNodeId,
          messageType: OfflinkMessageType.text,
          timestamp: DateTime.now().toUtc(),
          ttl: 4,
          payload: 'Hello Bob!',
        );

        transport.emit(packet);
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.first.messageId, equals('msg-local-1'));
        expect(transport.sent, isEmpty);

        await sub.cancel();
      },
    );

    test(
      'drops duplicate packets and emits to droppedPackets stream',
      () async {
        final inbound = <OfflinkPacket>[];
        final dropped = <OfflinkPacket>[];
        final sub1 = router.incomingPackets.listen(inbound.add);
        final sub2 = router.droppedPackets.listen(dropped.add);

        final packet = OfflinkPacket(
          messageId: 'msg-dup-1',
          senderNodeId: 'node-alice',
          recipientNodeId: localNodeId,
          messageType: OfflinkMessageType.text,
          timestamp: DateTime.now().toUtc(),
          ttl: 4,
          payload: 'Duplicate test',
        );

        transport.emit(packet);
        await Future<void>.delayed(Duration.zero);

        // Send duplicate
        transport.emit(packet);
        await Future<void>.delayed(Duration.zero);

        expect(inbound, hasLength(1));
        expect(dropped, hasLength(1));
        expect(dropped.first.messageId, equals('msg-dup-1'));

        await sub1.cancel();
        await sub2.cancel();
      },
    );

    test(
      'decrements TTL and forwards packet when acting as intermediate relay',
      () async {
        transport.connectedPeers = ['peer-alice', 'peer-charlie'];
        final forwarded = <OfflinkPacket>[];
        final sub = router.forwardedPackets.listen(forwarded.add);

        final packet = OfflinkPacket(
          messageId: 'msg-relay-1',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.encrypted,
          timestamp: DateTime.now().toUtc(),
          ttl: 4,
          payload: 'ENCRYPTED_CIPHERTEXT_BLOB',
        );

        // Packet arrives at relay Bob
        await router.onPacketReceived(packet, fromPeerId: 'peer-alice');

        expect(forwarded, hasLength(1));
        expect(forwarded.first.ttl, equals(3));
        // Preserves payload confidentiality intact
        expect(forwarded.first.payload, equals('ENCRYPTED_CIPHERTEXT_BLOB'));

        // Forwarded to Charlie, but split-horizon suppresses sending back to Alice
        expect(transport.sent, hasLength(1));
        expect(transport.sent.first.peerId, equals('peer-charlie'));
        expect(transport.sent.first.packet.ttl, equals(3));

        await sub.cancel();
      },
    );

    test('drops packet when TTL reaches 1 and does not forward', () async {
      transport.connectedPeers = ['peer-alice', 'peer-charlie'];
      final dropped = <OfflinkPacket>[];
      final sub = router.droppedPackets.listen(dropped.add);

      final packet = OfflinkPacket(
        messageId: 'msg-ttl-expire',
        senderNodeId: 'node-alice',
        recipientNodeId: 'node-charlie',
        messageType: OfflinkMessageType.text,
        timestamp: DateTime.now().toUtc(),
        ttl: 1, // Will expire
        payload: 'Expiring packet',
      );

      transport.emit(packet);
      await Future<void>.delayed(Duration.zero);

      expect(dropped, hasLength(1));
      expect(dropped.first.messageId, equals('msg-ttl-expire'));
      expect(transport.sent, isEmpty);

      await sub.cancel();
    });

    test('learns route back to sender on incoming packet', () async {
      transport.connectedPeers = ['peer-alice'];

      final packet = OfflinkPacket(
        messageId: 'msg-learn-route',
        senderNodeId: 'node-alice',
        recipientNodeId: localNodeId,
        messageType: OfflinkMessageType.text,
        timestamp: DateTime.now().toUtc(),
        ttl: 4,
        payload: 'Hi Bob',
      );

      await router.onPacketReceived(packet, fromPeerId: 'peer-alice');

      final route = router.routingTable.getRoute('node-alice');
      expect(route, isNotNull);
      expect(route!.destinationNodeId, equals('node-alice'));
      expect(route.nextHopPeerId, equals('peer-alice'));
      expect(route.hopCount, equals(1));
    });

    test(
      'broadcast packet is delivered locally and forwarded with decremented TTL',
      () async {
        transport.connectedPeers = ['peer-alice', 'peer-charlie'];
        final inbound = <OfflinkPacket>[];
        final forwarded = <OfflinkPacket>[];
        final sub1 = router.incomingPackets.listen(inbound.add);
        final sub2 = router.forwardedPackets.listen(forwarded.add);

        final broadcastPacket = OfflinkPacket(
          messageId: 'msg-bcast-1',
          senderNodeId: 'node-alice',
          recipientNodeId: '*',
          messageType: OfflinkMessageType.text,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: 'Emergency broadcast',
        );

        await router.onPacketReceived(
          broadcastPacket,
          fromPeerId: 'peer-alice',
        );

        expect(inbound, hasLength(1));
        expect(forwarded, hasLength(1));
        expect(forwarded.first.ttl, equals(2));
        // Split-horizon suppresses sending back to Alice
        expect(transport.sent, hasLength(1));
        expect(transport.sent.first.peerId, equals('peer-charlie'));

        await sub1.cancel();
        await sub2.cancel();
      },
    );

    test(
      'outbound sendPacket marks message in seenCache and routes to next hop',
      () async {
        transport.connectedPeers = ['peer-bob'];
        router.routingTable.updateRoute(
          destinationNodeId: 'node-charlie',
          nextHopPeerId: 'peer-bob',
          hopCount: 2,
        );

        final packet = OfflinkPacket(
          messageId: 'msg-out-1',
          senderNodeId: localNodeId,
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.text,
          timestamp: DateTime.now().toUtc(),
          ttl: 4,
          payload: 'To Charlie via Bob',
        );

        await router.sendPacket(peerId: 'node-charlie', packet: packet);

        // Packet marked as seen so loopbacks are dropped
        expect(router.seenCache.hasSeen('msg-out-1'), isTrue);

        // Sent to next hop peer-bob
        expect(transport.sent, hasLength(1));
        expect(transport.sent.first.peerId, equals('peer-bob'));
        expect(transport.sent.first.packet.messageId, equals('msg-out-1'));
      },
    );
  });
}
