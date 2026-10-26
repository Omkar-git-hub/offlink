import 'package:drift/drift.dart';

import '../../domain/messaging/chat_message.dart';
import '../../domain/messaging/message_repository.dart';
import 'offlink_database.dart';

/// Drift-backed implementation of [MessageRepository].
class DriftMessageRepository implements MessageRepository {
  DriftMessageRepository(this._db);

  final OfflinkDatabase _db;

  @override
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  }) async {
    await _db
        .into(_db.messagesTable)
        .insertOnConflictUpdate(
          MessagesTableCompanion.insert(
            id: message.id,
            conversationId: conversationId,
            senderNodeId: message.senderNodeId,
            recipientNodeId: message.recipientNodeId,
            content: message.content,
            timestamp: message.timestamp,
            status: message.status.name,
            isOutgoing: message.isOutgoing,
          ),
        );
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final query = _db.select(_db.messagesTable)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(_mapRowToEntity).toList();
  }

  @override
  Future<void> updateMessageStatus(
    String messageId,
    ChatMessageStatus status,
  ) async {
    final query = _db.update(_db.messagesTable)
      ..where((t) => t.id.equals(messageId));
    await query.write(MessagesTableCompanion(status: Value(status.name)));
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(
    String conversationId,
  ) {
    final query = _db.select(_db.messagesTable)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    return query.watch().map((rows) => rows.map(_mapRowToEntity).toList());
  }

  @override
  Future<void> deleteMessagesForConversation(String conversationId) async {
    final query = _db.delete(_db.messagesTable)
      ..where((t) => t.conversationId.equals(conversationId));
    await query.go();
  }

  ChatMessage _mapRowToEntity(MessagesTableData row) {
    return ChatMessage(
      id: row.id,
      conversationId: row.conversationId,
      senderNodeId: row.senderNodeId,
      recipientNodeId: row.recipientNodeId,
      content: row.content,
      timestamp: row.timestamp.toUtc(),
      isOutgoing: row.isOutgoing,
      status: _parseStatus(row.status),
    );
  }

  ChatMessageStatus _parseStatus(String statusStr) {
    switch (statusStr) {
      case 'sending':
        return ChatMessageStatus.sending;
      case 'sent':
        return ChatMessageStatus.sent;
      case 'delivered':
        return ChatMessageStatus.delivered;
      case 'failed':
        return ChatMessageStatus.failed;
      default:
        return ChatMessageStatus.delivered;
    }
  }
}
