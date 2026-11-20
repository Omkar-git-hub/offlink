import 'package:drift/drift.dart';

import 'groups_table.dart';

/// Drift table definition for storing group members.
class GroupMembersTable extends Table {
  TextColumn get groupId =>
      text().references(GroupsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get memberNodeId => text()();
  TextColumn get memberDisplayName => text()();
  TextColumn get role => text()(); // 'admin' or 'member'
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {groupId, memberNodeId};
}
