import 'group.dart';
import 'group_member.dart';

/// Repository interface for persisting and managing groups and their members.
abstract class GroupRepository {
  /// Creates a new group and persists its initial membership list.
  Future<void> createGroup(Group group, List<GroupMember> members);

  /// Retrieves a group by its unique [groupId], or null if not found.
  Future<Group?> getGroup(String groupId);

  /// Retrieves all local groups ordered by updated timestamp descending.
  Future<List<Group>> getAllGroups();

  /// Watches all local groups reactively.
  Stream<List<Group>> watchAllGroups();

  /// Retrieves all members belonging to [groupId].
  Future<List<GroupMember>> getGroupMembers(String groupId);

  /// Watches all members belonging to [groupId] reactively.
  Stream<List<GroupMember>> watchGroupMembers(String groupId);

  /// Adds a new [member] to the group.
  Future<void> addMember(String groupId, GroupMember member);

  /// Removes a member with [memberNodeId] from the group.
  Future<void> removeMember(String groupId, String memberNodeId);

  /// Updates existing group metadata (e.g. name or timestamp).
  Future<void> updateGroup(Group group);

  /// Deletes a group and cascades its members.
  Future<void> deleteGroup(String groupId);
}
