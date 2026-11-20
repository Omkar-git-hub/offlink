import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_group_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/group/group.dart';
import 'package:offlink/domain/group/group_member.dart';

void main() {
  late OfflinkDatabase db;
  late DriftGroupRepository repository;

  setUp(() {
    db = OfflinkDatabase.forTesting(NativeDatabase.memory());
    repository = DriftGroupRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftGroupRepository Tests', () {
    final now = DateTime.utc(2026, 11, 21, 1, 0);

    test('creates group and members atomically', () async {
      final group = Group(
        id: 'grp-1',
        name: 'Test Group',
        creatorNodeId: 'node-alice',
        createdAt: now,
        updatedAt: now,
      );

      final members = [
        GroupMember(
          groupId: 'grp-1',
          memberNodeId: 'node-alice',
          memberDisplayName: 'Alice',
          role: GroupMemberRole.admin,
          joinedAt: now,
        ),
        GroupMember(
          groupId: 'grp-1',
          memberNodeId: 'node-bob',
          memberDisplayName: 'Bob',
          role: GroupMemberRole.member,
          joinedAt: now,
        ),
      ];

      await repository.createGroup(group, members);

      final fetchedGroup = await repository.getGroup('grp-1');
      expect(fetchedGroup, isNotNull);
      expect(fetchedGroup!.id, equals('grp-1'));
      expect(fetchedGroup.name, equals('Test Group'));
      expect(fetchedGroup.creatorNodeId, equals('node-alice'));

      final fetchedMembers = await repository.getGroupMembers('grp-1');
      expect(fetchedMembers, hasLength(2));
      expect(fetchedMembers[0].memberNodeId, equals('node-alice'));
      expect(fetchedMembers[0].role, equals(GroupMemberRole.admin));
      expect(fetchedMembers[1].memberNodeId, equals('node-bob'));
      expect(fetchedMembers[1].role, equals(GroupMemberRole.member));
    });

    test('retrieves all groups and watches group changes', () async {
      final group1 = Group(
        id: 'grp-1',
        name: 'Alpha',
        creatorNodeId: 'node-alice',
        createdAt: now,
        updatedAt: now,
      );
      final group2 = Group(
        id: 'grp-2',
        name: 'Beta',
        creatorNodeId: 'node-alice',
        createdAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
      );

      await repository.createGroup(group1, []);
      await repository.createGroup(group2, []);

      final all = await repository.getAllGroups();
      expect(all, hasLength(2));
      expect(all.first.id, equals('grp-2')); // ordered by updatedAt desc

      expect(repository.watchAllGroups(), emits(hasLength(2)));
    });

    test('adds and removes members from group', () async {
      final group = Group(
        id: 'grp-1',
        name: 'Operations',
        creatorNodeId: 'node-alice',
        createdAt: now,
        updatedAt: now,
      );
      await repository.createGroup(group, []);

      final charlie = GroupMember(
        groupId: 'grp-1',
        memberNodeId: 'node-charlie',
        memberDisplayName: 'Charlie',
        role: GroupMemberRole.member,
        joinedAt: now,
      );

      await repository.addMember('grp-1', charlie);
      var members = await repository.getGroupMembers('grp-1');
      expect(members, hasLength(1));
      expect(members.first.memberNodeId, equals('node-charlie'));

      await repository.removeMember('grp-1', 'node-charlie');
      members = await repository.getGroupMembers('grp-1');
      expect(members, isEmpty);
    });

    test('updates group metadata and deletes group', () async {
      final group = Group(
        id: 'grp-1',
        name: 'Initial Name',
        creatorNodeId: 'node-alice',
        createdAt: now,
        updatedAt: now,
      );
      await repository.createGroup(group, []);

      final updated = group.copyWith(
        name: 'Updated Name',
        updatedAt: now.add(const Duration(hours: 1)),
      );
      await repository.updateGroup(updated);

      final fetched = await repository.getGroup('grp-1');
      expect(fetched?.name, equals('Updated Name'));

      await repository.deleteGroup('grp-1');
      expect(await repository.getGroup('grp-1'), isNull);
    });
  });
}
