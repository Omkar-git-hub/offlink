import 'package:drift/drift.dart';

/// Drift table definition for storing queued in-transit and store-and-forward packets.
class QueuedPacketsTable extends Table {
  TextColumn get id => text()(); // packet messageId
  TextColumn get senderNodeId => text()();
  TextColumn get recipientNodeId => text()();
  TextColumn get messageType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get ttl => integer()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
