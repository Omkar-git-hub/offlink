import 'dart:convert';

/// Payload structure for group chat messages exchanged over Offlink.
class GroupMessagePayload {
  const GroupMessagePayload({
    required this.messageId,
    required this.groupId,
    required this.groupName,
    required this.senderNodeId,
    required this.senderDisplayName,
    required this.content,
    required this.timestamp,
  });

  /// Canonical ID of the group message.
  final String messageId;

  /// Identifier of the target group.
  final String groupId;

  /// Name of the target group.
  final String groupName;

  /// Node ID of the message sender.
  final String senderNodeId;

  /// Display name of the message sender.
  final String senderDisplayName;

  /// Text content of the message.
  final String content;

  /// Timestamp when the message was sent (UTC).
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'groupId': groupId,
      'groupName': groupName,
      'senderNodeId': senderNodeId,
      'senderDisplayName': senderDisplayName,
      'content': content,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  String encode() => jsonEncode(toMap());

  factory GroupMessagePayload.fromMap(Map<String, dynamic> map) {
    return GroupMessagePayload(
      messageId: map['messageId'] as String,
      groupId: map['groupId'] as String,
      groupName: map['groupName'] as String,
      senderNodeId: map['senderNodeId'] as String,
      senderDisplayName: map['senderDisplayName'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  factory GroupMessagePayload.decode(String jsonString) {
    return GroupMessagePayload.fromMap(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMessagePayload &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          groupId == other.groupId &&
          groupName == other.groupName &&
          senderNodeId == other.senderNodeId &&
          senderDisplayName == other.senderDisplayName &&
          content == other.content &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      messageId.hashCode ^
      groupId.hashCode ^
      groupName.hashCode ^
      senderNodeId.hashCode ^
      senderDisplayName.hashCode ^
      content.hashCode ^
      timestamp.hashCode;
}
