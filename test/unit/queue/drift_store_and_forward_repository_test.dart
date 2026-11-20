import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_store_and_forward_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/queue/queued_packet.dart';

void main() {
  group('DriftStoreAndForwardRepository', () {
    late OfflinkDatabase db;
    late DriftStoreAndForwardRepository repository;

    setUp(() {
      db = OfflinkDatabase.forTesting(NativeDatabase.memory());
      repository = DriftStoreAndForwardRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('enqueues and retrieves queued packet with intact metadata', () async {
      final now = DateTime.utc(2026, 11, 21, 10, 0);
      final packet = QueuedPacket(
        id: 'pkt-100',
        senderNodeId: 'node-alice',
        recipientNodeId: 'node-charlie',
        messageType: OfflinkMessageType.encrypted,
        payload: '{"iv":"...","cipherText":"abc123xyz"}',
        timestamp: now,
        ttl: 4,
        createdAt: now,
        retryCount: 0,
        nextAttemptAt: now,
        status: QueuedPacketStatus.pending,
      );

      await repository.enqueuePacket(packet);

      final retrieved = await repository.getPacket('pkt-100');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('pkt-100'));
      expect(retrieved.senderNodeId, equals('node-alice'));
      expect(retrieved.recipientNodeId, equals('node-charlie'));
      expect(retrieved.messageType, equals(OfflinkMessageType.encrypted));
      expect(retrieved.payload, equals(packet.payload));
      expect(retrieved.ttl, equals(4));
      expect(retrieved.status, equals(QueuedPacketStatus.pending));
    });

    test('upserts on conflict to prevent duplicate queue entries', () async {
      final now = DateTime.utc(2026, 11, 21, 10, 0);
      final packet1 = QueuedPacket(
        id: 'pkt-dup-1',
        senderNodeId: 'node-alice',
        recipientNodeId: 'node-charlie',
        messageType: OfflinkMessageType.encrypted,
        payload: 'payload-v1',
        timestamp: now,
        ttl: 3,
        createdAt: now,
        retryCount: 0,
        nextAttemptAt: now,
      );

      await repository.enqueuePacket(packet1);

      // Re-enqueue same ID with updated attempt
      final packet2 = packet1.copyWith(payload: 'payload-v2', retryCount: 1);
      await repository.enqueuePacket(packet2);

      final size = await repository.getQueueSize();
      expect(size, equals(1));

      final retrieved = await repository.getPacket('pkt-dup-1');
      expect(retrieved!.payload, equals('payload-v2'));
      expect(retrieved.retryCount, equals(1));
    });

    test('updates packet status and retry parameters', () async {
      final now = DateTime.utc(2026, 11, 21, 10, 0);
      final packet = QueuedPacket(
        id: 'pkt-status',
        senderNodeId: 'node-alice',
        recipientNodeId: 'node-charlie',
        messageType: OfflinkMessageType.text,
        payload: 'Hello',
        timestamp: now,
        ttl: 3,
        createdAt: now,
        nextAttemptAt: now,
      );

      await repository.enqueuePacket(packet);

      final nextAttempt = now.add(const Duration(seconds: 15));
      await repository.updatePacketStatus(
        'pkt-status',
        QueuedPacketStatus.pending,
        retryCount: 2,
        nextAttemptAt: nextAttempt,
        ttl: 2,
      );

      final updated = await repository.getPacket('pkt-status');
      expect(updated!.retryCount, equals(2));
      expect(updated.nextAttemptAt, equals(nextAttempt));
      expect(updated.ttl, equals(2));

      await repository.updatePacketStatus(
        'pkt-status',
        QueuedPacketStatus.forwarded,
      );
      final forwarded = await repository.getPacket('pkt-status');
      expect(forwarded!.status, equals(QueuedPacketStatus.forwarded));
    });

    test('removes packet from queue upon ACK confirmation', () async {
      final now = DateTime.utc(2026, 11, 21, 10, 0);
      final packet = QueuedPacket(
        id: 'pkt-remove',
        senderNodeId: 'node-alice',
        recipientNodeId: 'node-charlie',
        messageType: OfflinkMessageType.text,
        payload: 'Test',
        timestamp: now,
        ttl: 3,
        createdAt: now,
        nextAttemptAt: now,
      );

      await repository.enqueuePacket(packet);
      expect(await repository.getQueueSize(), equals(1));

      await repository.removePacket('pkt-remove');
      expect(await repository.getQueueSize(), equals(0));
      expect(await repository.getPacket('pkt-remove'), isNull);
    });

    test(
      'prunes expired, terminal, and excess packets when maxQueueSize is exceeded',
      () async {
        final now = DateTime.now().toUtc();
        final ancient = now.subtract(const Duration(hours: 48));

        // 1. Ancient packet (exceeded maxAge)
        await repository.enqueuePacket(
          QueuedPacket(
            id: 'pkt-ancient',
            senderNodeId: 'node-a',
            recipientNodeId: 'node-b',
            messageType: OfflinkMessageType.text,
            payload: 'Old',
            timestamp: ancient,
            ttl: 3,
            createdAt: ancient,
            nextAttemptAt: ancient,
          ),
        );

        // 2. TTL exhausted packet (ttl <= 1)
        await repository.enqueuePacket(
          QueuedPacket(
            id: 'pkt-ttl-dead',
            senderNodeId: 'node-a',
            recipientNodeId: 'node-b',
            messageType: OfflinkMessageType.text,
            payload: 'Dead TTL',
            timestamp: now,
            ttl: 1,
            createdAt: now,
            nextAttemptAt: now,
          ),
        );

        // 3. Delivered/forwarded packet
        await repository.enqueuePacket(
          QueuedPacket(
            id: 'pkt-delivered',
            senderNodeId: 'node-a',
            recipientNodeId: 'node-b',
            messageType: OfflinkMessageType.text,
            payload: 'Delivered',
            timestamp: now,
            ttl: 3,
            createdAt: now,
            nextAttemptAt: now,
            status: QueuedPacketStatus.delivered,
          ),
        );

        // 4. Valid pending packets
        for (var i = 0; i < 5; i++) {
          await repository.enqueuePacket(
            QueuedPacket(
              id: 'pkt-valid-$i',
              senderNodeId: 'node-a',
              recipientNodeId: 'node-b',
              messageType: OfflinkMessageType.text,
              payload: 'Valid $i',
              timestamp: now,
              ttl: 3,
              createdAt: now.add(Duration(seconds: i)),
              nextAttemptAt: now,
            ),
          );
        }

        // Prune with maxQueueSize = 3
        final pruned = await repository.pruneExpired(
          maxAge: const Duration(hours: 24),
          maxQueueSize: 3,
        );

        expect(pruned, greaterThanOrEqualTo(3));

        final remainingSize = await repository.getQueueSize();
        expect(remainingSize, lessThanOrEqualTo(3));
        expect(await repository.getPacket('pkt-ancient'), isNull);
        expect(await repository.getPacket('pkt-ttl-dead'), isNull);
        expect(await repository.getPacket('pkt-delivered'), isNull);
      },
    );
  });
}
