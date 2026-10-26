/// Domain entity representing a conversation with a peer.
class Conversation {
  const Conversation({
    required this.id,
    required this.peerNodeId,
    required this.peerDisplayName,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  /// Unique conversation identifier (typically deterministic or UUID).
  final String id;

  /// Peer's unique node identifier.
  final String peerNodeId;

  /// Peer's human-readable display name.
  final String peerDisplayName;

  /// Preview snippet of the last message exchanged.
  final String? lastMessage;

  /// Number of unread incoming messages in this conversation.
  final int unreadCount;

  /// Last activity timestamp (UTC).
  final DateTime updatedAt;

  Conversation copyWith({
    String? id,
    String? peerNodeId,
    String? peerDisplayName,
    String? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      peerNodeId: peerNodeId ?? this.peerNodeId,
      peerDisplayName: peerDisplayName ?? this.peerDisplayName,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          peerNodeId == other.peerNodeId &&
          peerDisplayName == other.peerDisplayName &&
          lastMessage == other.lastMessage &&
          unreadCount == other.unreadCount &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    peerNodeId,
    peerDisplayName,
    lastMessage,
    unreadCount,
    updatedAt,
  );
}
