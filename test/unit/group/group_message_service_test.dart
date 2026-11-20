import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_group_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/group/group.dart';
import 'package:offlink/domain/group/group_member.dart';
import 'package:offlink/domain/group/group_message_service.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/protocol/group_message_payload.dart';
import 'package:offlink/domain/protocol/group_membership_payload.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

class FakePacketTransport implements PacketTransport {
  final StreamController<OfflinkPacket> _incomingController =
      StreamController<OfflinkPacket>.broadcast();

  final List<({String peerId, OfflinkPacket packet})> sentPackets = [];

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingController.stream;

  @override
  List<String> get connectedPeerIds => const [];

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    sentPackets.add((peerId: peerId, packet: packet));
  }

  void emit(OfflinkPacket packet) {
    _incomingController.add(packet);
  }

  Future<void> dispose() async {
    await _incomingController.close();
  }
}

class StubIdentityRepository implements IdentityRepository {
  StubIdentityRepository(this.identity);

  final OfflinkIdentity identity;

  @override
  Future<OfflinkIdentity?> loadIdentity() async => identity;

  @override
  Future<bool> hasIdentity() async => true;

  @override
  Future<void> saveIdentity(OfflinkIdentity identity) async {}

  @override
  Future<void> updateUsername(String username) async {}

  @override
  Future<void> clearIdentity() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflinkDatabase db;
  late DriftGroupRepository groupRepo;
  late DriftMessageRepository messageRepo;
  late DriftConversationRepository conversationRepo;
  late FakePacketTransport transport;
  late IdentityManager identityManager;
  late GroupMessageService service;

  final aliceIdentity = OfflinkIdentity(
    nodeId: 'node-alice',
    username: 'Alice',
    publicKey: 'alice-pub-key',
    createdAt: DateTime.utc(2026, 11, 21),
  );

  setUp(() async {
    db = OfflinkDatabase.forTesting(NativeDatabase.memory());
    groupRepo = DriftGroupRepository(db);
    messageRepo = DriftMessageRepository(db);
    conversationRepo = DriftConversationRepository(db);
    transport = FakePacketTransport();

    final idRepo = StubIdentityRepository(aliceIdentity);
    final keyService = IdentityKeyService();
    final initService = IdentityInitializationService(
      nodeIdGenerator: NodeIdGenerator(),
      keyService: keyService,
    );
    identityManager = IdentityManager(
      repository: idRepo,
      keyService: keyService,
      initializationService: initService,
    );
    await identityManager.loadExistingIdentity();

    service = GroupMessageService(
      packetTransport: transport,
      identityManager: identityManager,
      groupRepository: groupRepo,
      messageRepository: messageRepo,
      conversationRepository: conversationRepo,
    );
  });

  tearDown(() async {
    service.dispose();
    await transport.dispose();
    await db.close();
  });

  group('GroupMessageService Tests', () {
    test('creates group and dispatches membership invites to peers', () async {
      final bob = GroupMember(
        groupId: '',
        memberNodeId: 'node-bob',
        memberDisplayName: 'Bob',
        role: GroupMemberRole.member,
        joinedAt: DateTime.utc(2026, 11, 21),
      );
      final charlie = GroupMember(
        groupId: '',
        memberNodeId: 'node-charlie',
        memberDisplayName: 'Charlie',
        role: GroupMemberRole.member,
        joinedAt: DateTime.utc(2026, 11, 21),
      );

      final group = await service.createGroup(
        name: 'Project Offlink',
        initialMembers: [bob, charlie],
      );

      expect(group.name, equals('Project Offlink'));
      expect(group.creatorNodeId, equals('node-alice'));

      // Check group and members stored locally
      final storedGroup = await groupRepo.getGroup(group.id);
      expect(storedGroup, isNotNull);
      final storedMembers = await groupRepo.getGroupMembers(group.id);
      expect(storedMembers, hasLength(3)); // Alice (admin), Bob, Charlie

      // Check conversation created
      final conv = await conversationRepo.getConversationById(
        'group-${group.id}',
      );
      expect(conv, isNotNull);
      expect(conv!.peerDisplayName, equals('Project Offlink'));

      // Check membership packets sent to Bob and Charlie (not to Alice herself)
      expect(transport.sentPackets, hasLength(2));
      expect(transport.sentPackets.any((p) => p.peerId == 'node-bob'), isTrue);
      expect(
        transport.sentPackets.any((p) => p.peerId == 'node-charlie'),
        isTrue,
      );

      final bobPacket = transport.sentPackets
          .firstWhere((p) => p.peerId == 'node-bob')
          .packet;
      expect(bobPacket.messageType, equals(OfflinkMessageType.groupMembership));
      final payload = GroupMembershipPayload.decode(bobPacket.payload);
      expect(payload.action, equals('create'));
      expect(payload.groupName, equals('Project Offlink'));
      expect(payload.members, hasLength(3));
    });

    test('fans out group message to active members only', () async {
      final now = DateTime.utc(2026, 11, 21, 2, 0);
      final group = Group(
        id: 'grp-test',
        name: 'Team',
        creatorNodeId: 'node-alice',
        createdAt: now,
        updatedAt: now,
      );
      final members = [
        GroupMember(
          groupId: 'grp-test',
          memberNodeId: 'node-alice',
          memberDisplayName: 'Alice',
          role: GroupMemberRole.admin,
          joinedAt: now,
        ),
        GroupMember(
          groupId: 'grp-test',
          memberNodeId: 'node-bob',
          memberDisplayName: 'Bob',
          role: GroupMemberRole.member,
          joinedAt: now,
        ),
      ];
      await groupRepo.createGroup(group, members);

      final chatMessage = await service.sendGroupMessage(
        groupId: 'grp-test',
        content: 'Hello Team!',
      );

      expect(chatMessage.content, equals('Hello Team!'));
      expect(chatMessage.conversationId, equals('group-grp-test'));
      expect(chatMessage.isOutgoing, isTrue);
      expect(chatMessage.status, equals(ChatMessageStatus.sent));

      // Check message persisted locally
      final stored = await messageRepo.getMessageById(chatMessage.id);
      expect(stored, isNotNull);
      expect(stored!.content, equals('Hello Team!'));

      // Only Bob should receive wire packet
      expect(transport.sentPackets, hasLength(1));
      final sent = transport.sentPackets.first;
      expect(sent.peerId, equals('node-bob'));
      expect(sent.packet.recipientNodeId, equals('node-bob'));
      expect(sent.packet.messageType, equals(OfflinkMessageType.groupMessage));

      final payload = GroupMessagePayload.decode(sent.packet.payload);
      expect(payload.content, equals('Hello Team!'));
      expect(payload.groupId, equals('grp-test'));
    });

    test(
      'excludes removed member from future message fanouts (revocation secrecy)',
      () async {
        final now = DateTime.utc(2026, 11, 21, 2, 0);
        final group = Group(
          id: 'grp-test',
          name: 'Team',
          creatorNodeId: 'node-alice',
          createdAt: now,
          updatedAt: now,
        );
        final members = [
          GroupMember(
            groupId: 'grp-test',
            memberNodeId: 'node-alice',
            memberDisplayName: 'Alice',
            role: GroupMemberRole.admin,
            joinedAt: now,
          ),
          GroupMember(
            groupId: 'grp-test',
            memberNodeId: 'node-bob',
            memberDisplayName: 'Bob',
            role: GroupMemberRole.member,
            joinedAt: now,
          ),
          GroupMember(
            groupId: 'grp-test',
            memberNodeId: 'node-charlie',
            memberDisplayName: 'Charlie',
            role: GroupMemberRole.member,
            joinedAt: now,
          ),
        ];
        await groupRepo.createGroup(group, members);

        // Remove Charlie
        await service.removeMember(
          groupId: 'grp-test',
          memberNodeId: 'node-charlie',
        );
        transport.sentPackets.clear();

        // Send group message
        await service.sendGroupMessage(
          groupId: 'grp-test',
          content: 'Confidential after Charlie left',
        );

        // Must fan out to Bob, but NOT to Charlie!
        expect(transport.sentPackets, hasLength(1));
        expect(transport.sentPackets.first.peerId, equals('node-bob'));
        expect(
          transport.sentPackets.any((p) => p.peerId == 'node-charlie'),
          isFalse,
        );
      },
    );

    test(
      'receives group message, persists, updates conversation, and sends ACK',
      () async {
        final now = DateTime.utc(2026, 11, 21, 2, 0);
        final groupPayload = GroupMessagePayload(
          messageId: 'msg-remote-1',
          groupId: 'grp-remote',
          groupName: 'Remote Group',
          senderNodeId: 'node-bob',
          senderDisplayName: 'Bob',
          content: 'Hi Alice from Bob!',
          timestamp: now,
        );

        final packet = OfflinkPacket(
          messageId: 'packet-1',
          senderNodeId: 'node-bob',
          recipientNodeId: 'node-alice',
          messageType: OfflinkMessageType.groupMessage,
          timestamp: now,
          ttl: 4,
          payload: groupPayload.encode(),
        );

        final incomingFuture = service.incomingGroupMessages.first;
        transport.emit(packet);

        final receivedMsg = await incomingFuture;
        expect(receivedMsg.id, equals('msg-remote-1'));
        expect(receivedMsg.conversationId, equals('group-grp-remote'));
        expect(receivedMsg.content, equals('Hi Alice from Bob!'));
        expect(receivedMsg.isOutgoing, isFalse);

        // Check persisted in database
        final stored = await messageRepo.getMessageById('msg-remote-1');
        expect(stored, isNotNull);
        expect(stored!.content, equals('Hi Alice from Bob!'));

        // Check conversation updated
        final conv = await conversationRepo.getConversationById(
          'group-grp-remote',
        );
        expect(conv, isNotNull);
        expect(conv!.lastMessage, equals('Hi Alice from Bob!'));
        expect(conv.unreadCount, equals(1));

        // Check reverse-path ACK sent back to Bob
        expect(transport.sentPackets, hasLength(1));
        final ack = transport.sentPackets.first;
        expect(ack.peerId, equals('node-bob'));
        expect(
          ack.packet.messageType,
          equals(OfflinkMessageType.acknowledgement),
        );
        expect(ack.packet.payload, equals('packet-1'));
      },
    );

    test(
      'deduplicates incoming group message without duplicating unread count',
      () async {
        final now = DateTime.utc(2026, 11, 21, 2, 0);
        final groupPayload = GroupMessagePayload(
          messageId: 'msg-duplicate-1',
          groupId: 'grp-remote',
          groupName: 'Remote Group',
          senderNodeId: 'node-bob',
          senderDisplayName: 'Bob',
          content: 'First delivery',
          timestamp: now,
        );

        final packet = OfflinkPacket(
          messageId: 'packet-dup-1',
          senderNodeId: 'node-bob',
          recipientNodeId: 'node-alice',
          messageType: OfflinkMessageType.groupMessage,
          timestamp: now,
          ttl: 4,
          payload: groupPayload.encode(),
        );

        transport.emit(packet);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final convBefore = await conversationRepo.getConversationById(
          'group-grp-remote',
        );
        expect(convBefore?.unreadCount, equals(1));
        expect(transport.sentPackets, hasLength(1));

        // Emit duplicate packet
        transport.sentPackets.clear();
        transport.emit(packet);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should still send ACK, but not duplicate conversation unread count
        expect(transport.sentPackets, hasLength(1));
        final convAfter = await conversationRepo.getConversationById(
          'group-grp-remote',
        );
        expect(convAfter?.unreadCount, equals(1));
      },
    );

    test(
      'tracks delivery per member and updates message status upon ACK',
      () async {
        final now = DateTime.utc(2026, 11, 21, 2, 0);
        final group = Group(
          id: 'grp-ack-test',
          name: 'ACK Team',
          creatorNodeId: 'node-alice',
          createdAt: now,
          updatedAt: now,
        );
        final members = [
          GroupMember(
            groupId: 'grp-ack-test',
            memberNodeId: 'node-alice',
            memberDisplayName: 'Alice',
            role: GroupMemberRole.admin,
            joinedAt: now,
          ),
          GroupMember(
            groupId: 'grp-ack-test',
            memberNodeId: 'node-bob',
            memberDisplayName: 'Bob',
            role: GroupMemberRole.member,
            joinedAt: now,
          ),
        ];
        await groupRepo.createGroup(group, members);

        final sentMessage = await service.sendGroupMessage(
          groupId: 'grp-ack-test',
          content: 'Testing ACKs',
        );

        final statuses = service.getMemberDeliveryStatuses(sentMessage.id);
        expect(statuses['node-bob'], equals(ChatMessageStatus.sent));

        final packetSentToBob = transport.sentPackets.first.packet;

        // Simulate Bob sending ACK
        final ackPacket = OfflinkPacket(
          messageId: 'ack-bob-1',
          senderNodeId: 'node-bob',
          recipientNodeId: 'node-alice',
          messageType: OfflinkMessageType.acknowledgement,
          timestamp: DateTime.now().toUtc(),
          ttl: 4,
          payload: packetSentToBob.messageId,
        );

        transport.emit(ackPacket);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final updatedStatuses = service.getMemberDeliveryStatuses(
          sentMessage.id,
        );
        expect(
          updatedStatuses['node-bob'],
          equals(ChatMessageStatus.delivered),
        );

        final storedMessage = await messageRepo.getMessageById(sentMessage.id);
        expect(storedMessage?.status, equals(ChatMessageStatus.delivered));
      },
    );
  });
}
