import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/group/group.dart';
import 'package:offlink/domain/group/group_member.dart';
import 'package:offlink/domain/group/group_message_service.dart';
import 'package:offlink/domain/group/group_repository.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/message_repository.dart';
import 'package:offlink/features/chat/group_chat_page.dart';

class _FakeGroupRepository implements GroupRepository {
  final Map<String, Group> groups = {};
  final Map<String, List<GroupMember>> members = {};

  final StreamController<List<Group>> _groupsController =
      StreamController<List<Group>>.broadcast();
  final StreamController<List<GroupMember>> _membersController =
      StreamController<List<GroupMember>>.broadcast();

  @override
  Future<void> createGroup(
    Group group,
    List<GroupMember> initialMembers,
  ) async {
    groups[group.id] = group;
    members[group.id] = List.from(initialMembers);
    _groupsController.add(groups.values.toList());
  }

  @override
  Future<Group?> getGroup(String groupId) async => groups[groupId];

  @override
  Future<List<Group>> getAllGroups() async => groups.values.toList();

  @override
  Stream<List<Group>> watchAllGroups() => _groupsController.stream;

  @override
  Future<List<GroupMember>> getGroupMembers(String groupId) async =>
      members[groupId] ?? [];

  @override
  Stream<List<GroupMember>> watchGroupMembers(String groupId) =>
      _membersController.stream;

  @override
  Future<void> addMember(String groupId, GroupMember member) async {
    members.putIfAbsent(groupId, () => []).add(member);
    _membersController.add(members[groupId]!);
  }

  @override
  Future<void> removeMember(String groupId, String memberNodeId) async {
    members[groupId]?.removeWhere((m) => m.memberNodeId == memberNodeId);
    _membersController.add(members[groupId] ?? []);
  }

  @override
  Future<void> updateGroup(Group group) async {
    groups[group.id] = group;
    _groupsController.add(groups.values.toList());
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    groups.remove(groupId);
    members.remove(groupId);
  }

  void dispose() {
    _groupsController.close();
    _membersController.close();
  }
}

class _MockGroupMessageService implements GroupMessageService {
  final StreamController<ChatMessage> _incomingController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<Group> _groupEventsController =
      StreamController<Group>.broadcast();

  final List<({String groupId, String content})> sentMessages = [];

  @override
  Stream<ChatMessage> get incomingGroupMessages => _incomingController.stream;

  @override
  Stream<Group> get groupEvents => _groupEventsController.stream;

  @override
  Map<String, ChatMessageStatus> getMemberDeliveryStatuses(String messageId) =>
      {'node-bob': ChatMessageStatus.delivered};

  @override
  bool hasSecureSession(String peerNodeId) => true;

  @override
  Future<void> initiateSecureSessionsForGroup(String groupId) async {}

  @override
  Future<ChatMessage> sendGroupMessage({
    required String groupId,
    required String content,
  }) async {
    sentMessages.add((groupId: groupId, content: content));
    return ChatMessage(
      id: 'msg-test-${sentMessages.length}',
      conversationId: 'group-$groupId',
      senderNodeId: 'node-alice',
      recipientNodeId: groupId,
      content: content,
      timestamp: DateTime.now().toUtc(),
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMessageRepository implements MessageRepository {
  final List<ChatMessage> storedMessages = [];

  @override
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  }) async {
    storedMessages.add(message);
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async {
    return storedMessages
        .where((m) => m.conversationId == conversationId)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeGroupRepository groupRepo;
  late _MockGroupMessageService groupService;
  late _FakeMessageRepository messageRepo;

  final group = Group(
    id: 'grp-recon',
    name: 'Recon Team',
    creatorNodeId: 'node-alice',
    createdAt: DateTime.utc(2026, 11, 21),
    updatedAt: DateTime.utc(2026, 11, 21),
  );

  final members = [
    GroupMember(
      groupId: 'grp-recon',
      memberNodeId: 'node-alice',
      memberDisplayName: 'Alice',
      role: GroupMemberRole.admin,
      joinedAt: DateTime.utc(2026, 11, 21),
    ),
    GroupMember(
      groupId: 'grp-recon',
      memberNodeId: 'node-bob',
      memberDisplayName: 'Bob',
      role: GroupMemberRole.member,
      joinedAt: DateTime.utc(2026, 11, 21),
    ),
  ];

  setUp(() async {
    groupRepo = _FakeGroupRepository();
    await groupRepo.createGroup(group, members);
    groupService = _MockGroupMessageService();
    messageRepo = _FakeMessageRepository();
  });

  tearDown(() {
    groupRepo.dispose();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: GroupChatPage(
        group: group,
        groupMessageService: groupService,
        groupRepository: groupRepo,
        messageRepository: messageRepo,
        localNodeId: 'node-alice',
      ),
    );
  }

  testWidgets('renders group title and empty state', (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('Recon Team'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('No messages yet in Recon Team'), findsOneWidget);
  });

  testWidgets('sends group message and displays outgoing bubble', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    final inputField = find.byType(TextField);
    await tester.enterText(inputField, 'Hello Team!');
    await tester.pump();

    final sendButton = find.byIcon(Icons.send);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(find.text('Hello Team!'), findsOneWidget);
    expect(groupService.sentMessages, hasLength(1));
    expect(groupService.sentMessages.first.content, equals('Hello Team!'));
  });

  testWidgets('opens group details modal sheet and displays members', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    final infoButton = find.byIcon(Icons.info_outline);
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.text('Members (2)'), findsOneWidget);
    expect(find.text('Alice (You)'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
  });
}
