import '../protocol/offlink_message_type.dart';
import '../protocol/offlink_packet.dart';

/// Status of a packet in the store-and-forward or offline delivery queue.
enum QueuedPacketStatus { pending, forwarded, delivered, expired, failed }

/// Domain representation of a packet stored in the offline / store-and-forward queue.
class QueuedPacket {
  const QueuedPacket({
    required this.id,
    required this.senderNodeId,
    required this.recipientNodeId,
    required this.messageType,
    required this.payload,
    required this.timestamp,
    required this.ttl,
    required this.createdAt,
    this.retryCount = 0,
    required this.nextAttemptAt,
    this.status = QueuedPacketStatus.pending,
  });

  /// The original packet messageId.
  final String id;

  /// Origin node identifier.
  final String senderNodeId;

  /// Destination node identifier (or '*' for broadcast).
  final String recipientNodeId;

  /// Type of packet.
  final OfflinkMessageType messageType;

  /// The opaque payload (ciphertext for encrypted messages; plaintext for unencrypted text).
  /// Relay nodes must never inspect or decrypt this.
  final String payload;

  /// Original packet creation timestamp.
  final DateTime timestamp;

  /// Remaining hop count / TTL.
  final int ttl;

  /// When this packet was stored on the local node.
  final DateTime createdAt;

  /// Number of forwarding or delivery attempts made so far.
  final int retryCount;

  /// Next scheduled attempt timestamp.
  final DateTime nextAttemptAt;

  /// Current queue state.
  final QueuedPacketStatus status;

  /// Converts this queued record back into an [OfflinkPacket].
  OfflinkPacket toPacket() {
    return OfflinkPacket(
      messageId: id,
      senderNodeId: senderNodeId,
      recipientNodeId: recipientNodeId,
      messageType: messageType,
      timestamp: timestamp,
      ttl: ttl,
      payload: payload,
    );
  }

  /// Creates a [QueuedPacket] from an incoming or outgoing [OfflinkPacket].
  factory QueuedPacket.fromPacket(
    OfflinkPacket packet, {
    DateTime? createdAt,
    DateTime? nextAttemptAt,
    int retryCount = 0,
    QueuedPacketStatus status = QueuedPacketStatus.pending,
  }) {
    final now = DateTime.now().toUtc();
    return QueuedPacket(
      id: packet.messageId,
      senderNodeId: packet.senderNodeId,
      recipientNodeId: packet.recipientNodeId,
      messageType: packet.messageType,
      payload: packet.payload,
      timestamp: packet.timestamp,
      ttl: packet.ttl,
      createdAt: createdAt ?? now,
      retryCount: retryCount,
      nextAttemptAt: nextAttemptAt ?? now,
      status: status,
    );
  }

  QueuedPacket copyWith({
    String? id,
    String? senderNodeId,
    String? recipientNodeId,
    OfflinkMessageType? messageType,
    String? payload,
    DateTime? timestamp,
    int? ttl,
    DateTime? createdAt,
    int? retryCount,
    DateTime? nextAttemptAt,
    QueuedPacketStatus? status,
  }) {
    return QueuedPacket(
      id: id ?? this.id,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      recipientNodeId: recipientNodeId ?? this.recipientNodeId,
      messageType: messageType ?? this.messageType,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
    );
  }
}
