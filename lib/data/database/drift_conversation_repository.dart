import 'package:drift/drift.dart';

import '../../domain/messaging/conversation.dart';
import '../../domain/messaging/conversation_repository.dart';
import 'offlink_database.dart';

/// Drift-backed implementation of [ConversationRepository].
class DriftConversationRepository implements ConversationRepository {
  DriftConversationRepository(this._db);

  final OfflinkDatabase _db;

  @override
  Future<void> upsertConversation(Conversation conversation) async {
    await _db
        .into(_db.conversationsTable)
        .insertOnConflictUpdate(
          ConversationsTableCompanion.insert(
            id: conversation.id,
            peerNodeId: conversation.peerNodeId,
            peerDisplayName: conversation.peerDisplayName,
            lastMessage: Value(conversation.lastMessage),
            unreadCount: Value(conversation.unreadCount),
            updatedAt: conversation.updatedAt,
          ),
        );
  }

  @override
  Future<Conversation?> getConversationById(String conversationId) async {
    final query = _db.select(_db.conversationsTable)
      ..where((t) => t.id.equals(conversationId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapRowToEntity(row);
  }

  @override
  Future<Conversation?> getConversationByPeer(String peerNodeId) async {
    final query = _db.select(_db.conversationsTable)
      ..where((t) => t.peerNodeId.equals(peerNodeId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapRowToEntity(row);
  }

  @override
  Future<List<Conversation>> getAllConversations() async {
    final query = _db.select(_db.conversationsTable)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_mapRowToEntity).toList();
  }

  @override
  Stream<List<Conversation>> watchAllConversations() {
    final query = _db.select(_db.conversationsTable)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map(_mapRowToEntity).toList());
  }

  @override
  Future<void> markConversationAsRead(String conversationId) async {
    final query = _db.update(_db.conversationsTable)
      ..where((t) => t.id.equals(conversationId));
    await query.write(const ConversationsTableCompanion(unreadCount: Value(0)));
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final query = _db.delete(_db.conversationsTable)
      ..where((t) => t.id.equals(conversationId));
    await query.go();
  }

  Conversation _mapRowToEntity(ConversationsTableData row) {
    return Conversation(
      id: row.id,
      peerNodeId: row.peerNodeId,
      peerDisplayName: row.peerDisplayName,
      lastMessage: row.lastMessage,
      unreadCount: row.unreadCount,
      updatedAt: row.updatedAt.toUtc(),
    );
  }
}
