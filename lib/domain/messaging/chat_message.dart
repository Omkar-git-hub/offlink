enum ChatMessageStatus { sending, sent, delivered, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderNodeId,
    required this.recipientNodeId,
    required this.content,
    required this.timestamp,
    required this.isOutgoing,
    this.status = ChatMessageStatus.sent,
  });

  final String id;
  final String conversationId;
  final String senderNodeId;
  final String recipientNodeId;
  final String content;
  final DateTime timestamp;
  final bool isOutgoing;
  final ChatMessageStatus status;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderNodeId,
    String? recipientNodeId,
    String? content,
    DateTime? timestamp,
    bool? isOutgoing,
    ChatMessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      recipientNodeId: recipientNodeId ?? this.recipientNodeId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      status: status ?? this.status,
    );
  }
}
