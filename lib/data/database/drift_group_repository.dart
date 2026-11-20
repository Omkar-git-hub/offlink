import 'package:drift/drift.dart';

import '../../domain/group/group.dart';
import '../../domain/group/group_member.dart';
import '../../domain/group/group_repository.dart';
import 'offlink_database.dart';

/// Drift-backed implementation of [GroupRepository].
class DriftGroupRepository implements GroupRepository {
  DriftGroupRepository(this._db);

  final OfflinkDatabase _db;

  @override
  Future<void> createGroup(Group group, List<GroupMember> members) async {
    await _db.transaction(() async {
      await _db
          .into(_db.groupsTable)
          .insertOnConflictUpdate(
            GroupsTableCompanion.insert(
              id: group.id,
              name: group.name,
              creatorNodeId: group.creatorNodeId,
              createdAt: group.createdAt,
              updatedAt: group.updatedAt,
            ),
          );

      for (final member in members) {
        await _db
            .into(_db.groupMembersTable)
            .insertOnConflictUpdate(
              GroupMembersTableCompanion.insert(
                groupId: member.groupId,
                memberNodeId: member.memberNodeId,
                memberDisplayName: member.memberDisplayName,
                role: member.role.name,
                joinedAt: member.joinedAt,
              ),
            );
      }
    });
  }

  @override
  Future<Group?> getGroup(String groupId) async {
    final query = _db.select(_db.groupsTable)
      ..where((t) => t.id.equals(groupId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapGroupRow(row);
  }

  @override
  Future<List<Group>> getAllGroups() async {
    final query = _db.select(_db.groupsTable)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_mapGroupRow).toList();
  }

  @override
  Stream<List<Group>> watchAllGroups() {
    final query = _db.select(_db.groupsTable)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map((rows) => rows.map(_mapGroupRow).toList());
  }

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final query = _db.select(_db.groupMembersTable)
      ..where((t) => t.groupId.equals(groupId))
      ..orderBy([(t) => OrderingTerm.asc(t.joinedAt)]);
    final rows = await query.get();
    return rows.map(_mapMemberRow).toList();
  }

  @override
  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    final query = _db.select(_db.groupMembersTable)
      ..where((t) => t.groupId.equals(groupId))
      ..orderBy([(t) => OrderingTerm.asc(t.joinedAt)]);
    return query.watch().map((rows) => rows.map(_mapMemberRow).toList());
  }

  @override
  Future<void> addMember(String groupId, GroupMember member) async {
    await _db
        .into(_db.groupMembersTable)
        .insertOnConflictUpdate(
          GroupMembersTableCompanion.insert(
            groupId: groupId,
            memberNodeId: member.memberNodeId,
            memberDisplayName: member.memberDisplayName,
            role: member.role.name,
            joinedAt: member.joinedAt,
          ),
        );
  }

  @override
  Future<void> removeMember(String groupId, String memberNodeId) async {
    final query = _db.delete(_db.groupMembersTable)
      ..where(
        (t) => t.groupId.equals(groupId) & t.memberNodeId.equals(memberNodeId),
      );
    await query.go();
  }

  @override
  Future<void> updateGroup(Group group) async {
    await _db
        .update(_db.groupsTable)
        .replace(
          GroupsTableCompanion(
            id: Value(group.id),
            name: Value(group.name),
            creatorNodeId: Value(group.creatorNodeId),
            createdAt: Value(group.createdAt),
            updatedAt: Value(group.updatedAt),
          ),
        );
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final query = _db.delete(_db.groupsTable)
      ..where((t) => t.id.equals(groupId));
    await query.go();
  }

  Group _mapGroupRow(GroupsTableData row) {
    return Group(
      id: row.id,
      name: row.name,
      creatorNodeId: row.creatorNodeId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  GroupMember _mapMemberRow(GroupMembersTableData row) {
    return GroupMember(
      groupId: row.groupId,
      memberNodeId: row.memberNodeId,
      memberDisplayName: row.memberDisplayName,
      role: GroupMemberRole.fromString(row.role),
      joinedAt: row.joinedAt,
    );
  }
}
