import 'package:drift/drift.dart';

import '../../domain/protocol/offlink_message_type.dart';
import '../../domain/queue/queued_packet.dart';
import '../../domain/queue/store_and_forward_repository.dart';
import 'offlink_database.dart';

/// Drift-backed implementation of [StoreAndForwardRepository].
class DriftStoreAndForwardRepository implements StoreAndForwardRepository {
  DriftStoreAndForwardRepository(this._db);

  final OfflinkDatabase _db;

  @override
  Future<void> enqueuePacket(QueuedPacket packet) async {
    await _db
        .into(_db.queuedPacketsTable)
        .insertOnConflictUpdate(
          QueuedPacketsTableCompanion.insert(
            id: packet.id,
            senderNodeId: packet.senderNodeId,
            recipientNodeId: packet.recipientNodeId,
            messageType: packet.messageType.name,
            payload: packet.payload,
            timestamp: packet.timestamp,
            ttl: packet.ttl,
            createdAt: packet.createdAt,
            retryCount: Value(packet.retryCount),
            nextAttemptAt: packet.nextAttemptAt,
            status: Value(packet.status.name),
          ),
        );
  }

  @override
  Future<QueuedPacket?> getPacket(String id) async {
    final query = _db.select(_db.queuedPacketsTable)
      ..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return _mapRowToEntity(row);
  }

  @override
  Future<List<QueuedPacket>> getPendingPackets({
    String? recipientNodeId,
    int limit = 50,
  }) async {
    final query = _db.select(_db.queuedPacketsTable)
      ..where((t) {
        var predicate = t.status.equals(QueuedPacketStatus.pending.name);
        if (recipientNodeId != null) {
          predicate = predicate & t.recipientNodeId.equals(recipientNodeId);
        }
        return predicate;
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.nextAttemptAt),
        (t) => OrderingTerm.asc(t.createdAt),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_mapRowToEntity).toList();
  }

  @override
  Future<void> updatePacketStatus(
    String id,
    QueuedPacketStatus status, {
    int? retryCount,
    DateTime? nextAttemptAt,
    int? ttl,
  }) async {
    final query = _db.update(_db.queuedPacketsTable)
      ..where((t) => t.id.equals(id));

    await query.write(
      QueuedPacketsTableCompanion(
        status: Value(status.name),
        retryCount: retryCount != null
            ? Value(retryCount)
            : const Value.absent(),
        nextAttemptAt: nextAttemptAt != null
            ? Value(nextAttemptAt)
            : const Value.absent(),
        ttl: ttl != null ? Value(ttl) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> removePacket(String id) async {
    final query = _db.delete(_db.queuedPacketsTable)
      ..where((t) => t.id.equals(id));
    await query.go();
  }

  @override
  Future<int> pruneExpired({
    Duration maxAge = const Duration(hours: 24),
    int maxQueueSize = 200,
  }) async {
    var prunedCount = 0;
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(maxAge);

    // 1. Delete terminal non-pending rows (delivered, expired, failed)
    final terminalQuery = _db.delete(_db.queuedPacketsTable)
      ..where((t) => t.status.isNotValue(QueuedPacketStatus.pending.name));
    prunedCount += await terminalQuery.go();

    // 2. Mark/delete pending rows that exceeded maxAge or have expired TTL
    final expiredQuery = _db.delete(_db.queuedPacketsTable)
      ..where(
        (t) =>
            t.status.equals(QueuedPacketStatus.pending.name) &
            (t.createdAt.isSmallerThanValue(cutoff) |
                t.ttl.isSmallerOrEqualValue(1)),
      );
    prunedCount += await expiredQuery.go();

    // 3. Enforce maximum bounded queue capacity: delete oldest excess pending entries
    final currentPending = await getPendingPackets(limit: maxQueueSize + 100);
    if (currentPending.length > maxQueueSize) {
      final excessCount = currentPending.length - maxQueueSize;
      final oldestExcess = currentPending.reversed.take(excessCount);
      for (final packet in oldestExcess) {
        await removePacket(packet.id);
        prunedCount++;
      }
    }

    return prunedCount;
  }

  @override
  Future<int> getQueueSize() async {
    final countExp = _db.queuedPacketsTable.id.count();
    final query = _db.selectOnly(_db.queuedPacketsTable)
      ..addColumns([countExp])
      ..where(
        _db.queuedPacketsTable.status.equals(QueuedPacketStatus.pending.name),
      );
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  QueuedPacket _mapRowToEntity(QueuedPacketsTableData row) {
    return QueuedPacket(
      id: row.id,
      senderNodeId: row.senderNodeId,
      recipientNodeId: row.recipientNodeId,
      messageType: _parseMessageType(row.messageType),
      payload: row.payload,
      timestamp: row.timestamp.toUtc(),
      ttl: row.ttl,
      createdAt: row.createdAt.toUtc(),
      retryCount: row.retryCount,
      nextAttemptAt: row.nextAttemptAt.toUtc(),
      status: _parseStatus(row.status),
    );
  }

  OfflinkMessageType _parseMessageType(String typeStr) {
    for (final type in OfflinkMessageType.values) {
      if (type.name == typeStr) return type;
    }
    return OfflinkMessageType.text;
  }

  QueuedPacketStatus _parseStatus(String statusStr) {
    for (final status in QueuedPacketStatus.values) {
      if (status.name == statusStr) return status;
    }
    return QueuedPacketStatus.pending;
  }
}
