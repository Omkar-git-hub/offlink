import 'package:drift/drift.dart';

import 'conversations_table.dart';

/// Drift table definition for storing individual chat messages.
class MessagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(ConversationsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get senderNodeId => text()();
  TextColumn get recipientNodeId => text()();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get status => text()();
  BoolColumn get isOutgoing => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}
