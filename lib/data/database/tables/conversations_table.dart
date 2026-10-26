import 'package:drift/drift.dart';

/// Drift table definition for storing conversation summaries.
class ConversationsTable extends Table {
  TextColumn get id => text()();
  TextColumn get peerNodeId => text()();
  TextColumn get peerDisplayName => text()();
  TextColumn get lastMessage => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
