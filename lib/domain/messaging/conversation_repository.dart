import 'conversation.dart';

/// Abstract repository contract for managing conversations.
abstract class ConversationRepository {
  /// Inserts or updates an existing [conversation].
  Future<void> upsertConversation(Conversation conversation);

  /// Retrieves a conversation by its unique [conversationId], or null if not found.
  Future<Conversation?> getConversationById(String conversationId);

  /// Retrieves a conversation associated with [peerNodeId], or null if not found.
  Future<Conversation?> getConversationByPeer(String peerNodeId);

  /// Retrieves all conversations ordered by last update descending.
  Future<List<Conversation>> getAllConversations();

  /// Watches all conversations ordered by last update descending.
  Stream<List<Conversation>> watchAllConversations();

  /// Marks unread count as 0 for [conversationId].
  Future<void> markConversationAsRead(String conversationId);

  /// Deletes a conversation by its [conversationId].
  Future<void> deleteConversation(String conversationId);
}
