import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/mesh/routing_table.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/domain/queue/queued_packet.dart';
import 'package:offlink/domain/queue/store_and_forward_manager.dart';
import 'package:offlink/domain/queue/store_and_forward_repository.dart';

class _InMemoryStoreAndForwardRepo implements StoreAndForwardRepository {
  final Map<String, QueuedPacket> packets = {};

  @override
  Future<void> enqueuePacket(QueuedPacket packet) async {
    packets[packet.id] = packet;
  }

  @override
  Future<QueuedPacket?> getPacket(String id) async => packets[id];

  @override
  Future<List<QueuedPacket>> getPendingPackets({
    String? recipientNodeId,
    int limit = 50,
  }) async {
    return packets.values
        .where(
          (p) =>
              p.status == QueuedPacketStatus.pending &&
              (recipientNodeId == null || p.recipientNodeId == recipientNodeId),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> updatePacketStatus(
    String id,
    QueuedPacketStatus status, {
    int? retryCount,
    DateTime? nextAttemptAt,
    int? ttl,
  }) async {
    final existing = packets[id];
    if (existing != null) {
      packets[id] = existing.copyWith(
        status: status,
        retryCount: retryCount ?? existing.retryCount,
        nextAttemptAt: nextAttemptAt ?? existing.nextAttemptAt,
        ttl: ttl ?? existing.ttl,
      );
    }
  }

  @override
  Future<void> removePacket(String id) async {
    packets.remove(id);
  }

  @override
  Future<int> pruneExpired({
    Duration maxAge = const Duration(hours: 24),
    int maxQueueSize = 200,
  }) async {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(maxAge);
    final toRemove = <String>[];
    for (final p in packets.values) {
      if (p.status != QueuedPacketStatus.pending ||
          p.createdAt.isBefore(cutoff) ||
          p.ttl <= 1) {
        toRemove.add(p.id);
      }
    }
    for (final id in toRemove) {
      packets.remove(id);
    }
    return toRemove.length;
  }

  @override
  Future<int> getQueueSize() async => packets.values
      .where((p) => p.status == QueuedPacketStatus.pending)
      .length;
}

class _MockPacketTransport implements PacketTransport {
  final List<String> peers = [];
  final List<OfflinkPacket> sentPackets = [];
  bool shouldThrowOnSend = false;

  @override
  List<String> get connectedPeerIds => List.unmodifiable(peers);

  @override
  Stream<OfflinkPacket> get incomingPackets => const Stream.empty();

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    if (shouldThrowOnSend) {
      throw StateError('Simulated transport link failure');
    }
    sentPackets.add(packet);
  }
}

void main() {
  group('StoreAndForwardManager', () {
    late _InMemoryStoreAndForwardRepo repository;
    late _MockPacketTransport transport;
    late RoutingTable routingTable;
    late StoreAndForwardManager manager;

    setUp(() {
      repository = _InMemoryStoreAndForwardRepo();
      transport = _MockPacketTransport();
      routingTable = RoutingTable();
      manager = StoreAndForwardManager(
        repository: repository,
        transport: transport,
        routingTable: routingTable,
        getLocalNodeId: () => 'node-relay-bob',
        getConnectedPeerIds: () => transport.peers,
        checkInterval: const Duration(milliseconds: 100),
        initialBackoff: Duration.zero,
        maxRetries: 3,
      );
    });

    tearDown(() {
      manager.dispose();
    });

    test(
      'enqueues eligible in-transit packet without inspecting payload',
      () async {
        final now = DateTime.now().toUtc();
        final packet = OfflinkPacket(
          messageId: 'msg-alice-to-charlie',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.encrypted,
          payload: 'encrypted-secret-ciphertext',
          timestamp: now,
          ttl: 3,
        );

        final enqueued = await manager.enqueueInTransitPacket(packet);
        expect(enqueued, isTrue);

        final stored = await repository.getPacket('msg-alice-to-charlie');
        expect(stored, isNotNull);
        expect(stored!.payload, equals('encrypted-secret-ciphertext'));
        expect(stored.senderNodeId, equals('node-alice'));
        expect(stored.recipientNodeId, equals('node-charlie'));
        expect(stored.status, equals(QueuedPacketStatus.pending));
      },
    );

    test(
      'rejects packet destined for local node, broadcast, or exhausted TTL',
      () async {
        final now = DateTime.now().toUtc();

        // Local recipient
        final localPkt = OfflinkPacket(
          messageId: 'pkt-local',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-relay-bob',
          messageType: OfflinkMessageType.text,
          payload: 'Hi Bob',
          timestamp: now,
          ttl: 3,
        );
        expect(await manager.enqueueInTransitPacket(localPkt), isFalse);

        // Broadcast recipient
        final bcastPkt = OfflinkPacket(
          messageId: 'pkt-bcast',
          senderNodeId: 'node-alice',
          recipientNodeId: '*',
          messageType: OfflinkMessageType.text,
          payload: 'Broadcast',
          timestamp: now,
          ttl: 3,
        );
        expect(await manager.enqueueInTransitPacket(bcastPkt), isFalse);

        // Exhausted TTL (<= 1)
        final deadTtlPkt = OfflinkPacket(
          messageId: 'pkt-dead',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.text,
          payload: 'Dead',
          timestamp: now,
          ttl: 1,
        );
        expect(await manager.enqueueInTransitPacket(deadTtlPkt), isFalse);
      },
    );

    test(
      'flushes stored packet when recipient connects directly and decrements TTL',
      () async {
        final now = DateTime.now().toUtc();
        final packet = OfflinkPacket(
          messageId: 'msg-stored-1',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.encrypted,
          payload: 'encrypted-bytes',
          timestamp: now,
          ttl: 3,
        );

        await manager.enqueueInTransitPacket(packet);
        expect(transport.sentPackets, isEmpty);

        // Charlie connects to Bob
        transport.peers.add('node-charlie');

        final forwarded = await manager.onPeerOrRouteAvailable('node-charlie');
        expect(forwarded, equals(1));
        expect(transport.sentPackets, hasLength(1));

        final sent = transport.sentPackets.first;
        expect(sent.messageId, equals('msg-stored-1'));
        expect(sent.recipientNodeId, equals('node-charlie'));
        // TTL decremented from 3 to 2
        expect(sent.ttl, equals(2));

        final stored = await repository.getPacket('msg-stored-1');
        expect(stored!.status, equals(QueuedPacketStatus.forwarded));
      },
    );

    test(
      'removes queued packet immediately when matching ACK is received',
      () async {
        final now = DateTime.now().toUtc();
        final packet = OfflinkPacket(
          messageId: 'msg-ack-test',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.encrypted,
          payload: 'cipher',
          timestamp: now,
          ttl: 3,
        );

        await manager.enqueueInTransitPacket(packet);
        expect(await repository.getQueueSize(), equals(1));

        // ACK arrives for messageId
        await manager.onAckReceived('msg-ack-test');
        expect(await repository.getQueueSize(), equals(0));
        expect(await repository.getPacket('msg-ack-test'), isNull);
      },
    );

    test(
      'increments retry count on transmission failure and marks failed after maxRetries',
      () async {
        final now = DateTime.now().toUtc();
        final packet = OfflinkPacket(
          messageId: 'msg-fail-test',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-charlie',
          messageType: OfflinkMessageType.text,
          payload: 'Fail test',
          timestamp: now,
          ttl: 3,
        );

        await manager.enqueueInTransitPacket(packet);
        transport.peers.add('node-charlie');
        transport.shouldThrowOnSend = true;

        // Attempt 1
        await manager.flushEligiblePackets();
        var stored = await repository.getPacket('msg-fail-test');
        expect(stored!.retryCount, equals(1));
        expect(stored.status, equals(QueuedPacketStatus.pending));

        // Attempt 2
        await manager.flushEligiblePackets();
        stored = await repository.getPacket('msg-fail-test');
        expect(stored!.retryCount, equals(2));

        // Attempt 3: reaches maxRetries (3)
        await manager.flushEligiblePackets();
        stored = await repository.getPacket('msg-fail-test');
        expect(stored!.status, equals(QueuedPacketStatus.failed));
      },
    );
  });
}
