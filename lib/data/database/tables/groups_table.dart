import 'package:drift/drift.dart';

/// Drift table definition for storing groups.
class GroupsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get creatorNodeId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
