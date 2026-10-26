import 'chat_message.dart';

/// Abstract repository contract for persisting and retrieving chat messages.
abstract class MessageRepository {
  /// Persists a new [message] linked to [conversationId].
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  });

  /// Retrieves messages for [conversationId] ordered chronologically.
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  });

  /// Updates the delivery [status] of an existing message by its [messageId].
  Future<void> updateMessageStatus(String messageId, ChatMessageStatus status);

  /// Streams list of messages for [conversationId] ordered chronologically.
  Stream<List<ChatMessage>> watchMessagesForConversation(String conversationId);

  /// Deletes all messages in a conversation.
  Future<void> deleteMessagesForConversation(String conversationId);
}
