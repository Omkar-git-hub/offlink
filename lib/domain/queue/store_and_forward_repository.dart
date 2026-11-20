import 'queued_packet.dart';

/// Abstract repository interface for persisting and managing store-and-forward packets.
abstract class StoreAndForwardRepository {
  /// Enqueues a packet into persistent storage.
  /// If a packet with the same ID already exists, it updates the record.
  Future<void> enqueuePacket(QueuedPacket packet);

  /// Retrieves a specific queued packet by its unique [id] (packet messageId).
  Future<QueuedPacket?> getPacket(String id);

  /// Retrieves pending packets ready for forwarding or delivery,
  /// optionally filtered by [recipientNodeId].
  Future<List<QueuedPacket>> getPendingPackets({
    String? recipientNodeId,
    int limit = 50,
  });

  /// Updates the queue [status] of a packet, with optional updated [retryCount],
  /// [nextAttemptAt], and remaining [ttl].
  Future<void> updatePacketStatus(
    String id,
    QueuedPacketStatus status, {
    int? retryCount,
    DateTime? nextAttemptAt,
    int? ttl,
  });

  /// Removes a packet permanently from the queue (e.g. upon ACK confirmation).
  Future<void> removePacket(String id);

  /// Enforces storage bounds and TTL:
  /// - Removes non-pending packets (delivered, expired, failed) older than 1 hour.
  /// - Marks or removes packets older than [maxAge] or with [ttl] <= 1.
  /// - If active queue size exceeds [maxQueueSize], evicts oldest excess items.
  /// Returns the number of pruned packets.
  Future<int> pruneExpired({
    Duration maxAge = const Duration(hours: 24),
    int maxQueueSize = 200,
  });

  /// Returns total count of pending packets currently stored.
  Future<int> getQueueSize();
}
