import 'package:drift/drift.dart';

/// Drift table definition for storing locally blocked peers.
class BlockedPeersTable extends Table {
  TextColumn get nodeId => text()();
  DateTimeColumn get blockedAt => dateTime()();
  TextColumn get reason => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {nodeId};
}
