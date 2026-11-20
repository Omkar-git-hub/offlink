import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_group_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/drift_store_and_forward_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/group/group_member.dart';
import 'package:offlink/domain/group/group_message_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/mesh/seen_message_cache.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/domain/queue/store_and_forward_manager.dart';

import '../identity/fakes/fake_secure_key_storage.dart';

class _SimulatedMeshNetwork {
  final Map<String, _SimulatedNodeTransport> nodes = {};
  final Set<String> activeLinks = {};

  void registerNode(String nodeId, _SimulatedNodeTransport transport) {
    nodes[nodeId] = transport;
  }

  void link(String nodeA, String nodeB) {
    activeLinks.add('$nodeA<->$nodeB');
    activeLinks.add('$nodeB<->$nodeA');
    nodes[nodeA]?.connectedNeighbors.add(nodeB);
    nodes[nodeB]?.connectedNeighbors.add(nodeA);
  }

  void unlink(String nodeA, String nodeB) {
    activeLinks.remove('$nodeA<->$nodeB');
    activeLinks.remove('$nodeB<->$nodeA');
    nodes[nodeA]?.connectedNeighbors.remove(nodeB);
    nodes[nodeB]?.connectedNeighbors.remove(nodeA);
  }

  bool isLinked(String nodeA, String nodeB) {
    return activeLinks.contains('$nodeA<->$nodeB');
  }

  Future<void> route(
    String fromNode,
    String toNode,
    OfflinkPacket packet,
  ) async {
    if (!isLinked(fromNode, toNode)) {
      throw StateError('Link between $fromNode and $toNode is down');
    }
    final dest = nodes[toNode];
    if (dest != null) {
      dest.receive(packet, fromNode);
    }
  }
}

class _SimulatedNodeTransport implements PacketTransport {
  _SimulatedNodeTransport({required this.nodeId, required this.network});

  final String nodeId;
  final _SimulatedMeshNetwork network;
  final Set<String> connectedNeighbors = {};
  final StreamController<OfflinkPacket> _incomingController =
      StreamController<OfflinkPacket>.broadcast();

  @override
  List<String> get connectedPeerIds => connectedNeighbors.toList();

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingController.stream;

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    await network.route(nodeId, peerId, packet);
  }

  void receive(OfflinkPacket packet, String fromPeer) {
    _incomingController.add(packet);
  }

  void dispose() {
    _incomingController.close();
  }
}

class _TestIdentityManager implements IdentityManager {
  _TestIdentityManager(this.nodeId);
  final String nodeId;

  @override
  OfflinkIdentity? get currentIdentity => OfflinkIdentity(
    nodeId: nodeId,
    username: 'Node $nodeId',
    publicKey: 'pub-$nodeId',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Group Messaging Mesh & Store-and-Forward Integration (4-Node Simulation)', () {
    late _SimulatedMeshNetwork network;

    // Alice (Group Admin)
    late OfflinkDatabase aliceDb;
    late DriftGroupRepository aliceGroupRepo;
    late DriftMessageRepository aliceMsgRepo;
    late DriftConversationRepository aliceConvRepo;
    late _SimulatedNodeTransport aliceTransport;
    late MeshPacketRouter aliceRouter;
    late IdentityKeyService aliceKeyService;
    late SecureSessionService aliceSessionService;
    late GroupMessageService aliceGroupService;

    // David (Intermediate Relay Node)
    late OfflinkDatabase davidDb;
    late DriftStoreAndForwardRepository davidStoreForwardRepo;
    late _SimulatedNodeTransport davidTransport;
    late MeshPacketRouter davidRouter;
    late StoreAndForwardManager davidStoreForwardManager;

    // Bob (Group Member)
    late OfflinkDatabase bobDb;
    late DriftGroupRepository bobGroupRepo;
    late DriftMessageRepository bobMsgRepo;
    late DriftConversationRepository bobConvRepo;
    late _SimulatedNodeTransport bobTransport;
    late MeshPacketRouter bobRouter;
    late IdentityKeyService bobKeyService;
    late SecureSessionService bobSessionService;
    late GroupMessageService bobGroupService;

    // Charlie (Group Member)
    late OfflinkDatabase charlieDb;
    late DriftGroupRepository charlieGroupRepo;
    late DriftMessageRepository charlieMsgRepo;
    late DriftConversationRepository charlieConvRepo;
    late _SimulatedNodeTransport charlieTransport;
    late MeshPacketRouter charlieRouter;
    late IdentityKeyService charlieKeyService;
    late SecureSessionService charlieSessionService;
    late GroupMessageService charlieGroupService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      network = _SimulatedMeshNetwork();

      // 1. Setup Alice
      aliceDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      aliceGroupRepo = DriftGroupRepository(aliceDb);
      aliceMsgRepo = DriftMessageRepository(aliceDb);
      aliceConvRepo = DriftConversationRepository(aliceDb);
      aliceTransport = _SimulatedNodeTransport(
        nodeId: 'node-alice',
        network: network,
      );
      aliceRouter = MeshPacketRouter(
        transport: aliceTransport,
        getLocalNodeId: () => 'node-alice',
        seenCache: SeenMessageCache(entryTtl: const Duration(seconds: 3)),
      );
      final aliceKeyStorage = FakeSecureKeyStorage();
      aliceKeyService = IdentityKeyService(secureStorage: aliceKeyStorage);
      final aliceKeyPair = await aliceKeyService.generateKeyPair();
      await aliceKeyService.storePrivateKey(aliceKeyPair.privateKey);
      aliceSessionService = SecureSessionService(
        identityKeyService: aliceKeyService,
        getLocalNodeId: () => 'node-alice',
      );
      aliceGroupService = GroupMessageService(
        packetTransport: aliceRouter,
        identityManager: _TestIdentityManager('node-alice'),
        groupRepository: aliceGroupRepo,
        messageRepository: aliceMsgRepo,
        conversationRepository: aliceConvRepo,
        secureSessionService: aliceSessionService,
      );
      network.registerNode('node-alice', aliceTransport);

      // 2. Setup David (Relay Node - NO crypto keys for users!)
      davidDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      davidStoreForwardRepo = DriftStoreAndForwardRepository(davidDb);
      davidTransport = _SimulatedNodeTransport(
        nodeId: 'node-david',
        network: network,
      );
      davidRouter = MeshPacketRouter(
        transport: davidTransport,
        getLocalNodeId: () => 'node-david',
        seenCache: SeenMessageCache(entryTtl: const Duration(seconds: 3)),
      );
      davidStoreForwardManager = StoreAndForwardManager(
        repository: davidStoreForwardRepo,
        transport: davidTransport,
        routingTable: davidRouter.routingTable,
        getLocalNodeId: () => 'node-david',
        getConnectedPeerIds: () => davidTransport.connectedPeerIds,
        initialBackoff: Duration.zero,
      );
      davidRouter.storeAndForwardManager = davidStoreForwardManager;
      network.registerNode('node-david', davidTransport);

      // 3. Setup Bob
      bobDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      bobGroupRepo = DriftGroupRepository(bobDb);
      bobMsgRepo = DriftMessageRepository(bobDb);
      bobConvRepo = DriftConversationRepository(bobDb);
      bobTransport = _SimulatedNodeTransport(
        nodeId: 'node-bob',
        network: network,
      );
      bobRouter = MeshPacketRouter(
        transport: bobTransport,
        getLocalNodeId: () => 'node-bob',
        seenCache: SeenMessageCache(entryTtl: const Duration(seconds: 3)),
      );
      final bobKeyStorage = FakeSecureKeyStorage();
      bobKeyService = IdentityKeyService(secureStorage: bobKeyStorage);
      final bobKeyPair = await bobKeyService.generateKeyPair();
      await bobKeyService.storePrivateKey(bobKeyPair.privateKey);
      bobSessionService = SecureSessionService(
        identityKeyService: bobKeyService,
        getLocalNodeId: () => 'node-bob',
      );
      bobGroupService = GroupMessageService(
        packetTransport: bobRouter,
        identityManager: _TestIdentityManager('node-bob'),
        groupRepository: bobGroupRepo,
        messageRepository: bobMsgRepo,
        conversationRepository: bobConvRepo,
        secureSessionService: bobSessionService,
      );
      network.registerNode('node-bob', bobTransport);

      // 4. Setup Charlie
      charlieDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      charlieGroupRepo = DriftGroupRepository(charlieDb);
      charlieMsgRepo = DriftMessageRepository(charlieDb);
      charlieConvRepo = DriftConversationRepository(charlieDb);
      charlieTransport = _SimulatedNodeTransport(
        nodeId: 'node-charlie',
        network: network,
      );
      charlieRouter = MeshPacketRouter(
        transport: charlieTransport,
        getLocalNodeId: () => 'node-charlie',
        seenCache: SeenMessageCache(entryTtl: const Duration(seconds: 3)),
      );
      final charlieKeyStorage = FakeSecureKeyStorage();
      charlieKeyService = IdentityKeyService(secureStorage: charlieKeyStorage);
      final charlieKeyPair = await charlieKeyService.generateKeyPair();
      await charlieKeyService.storePrivateKey(charlieKeyPair.privateKey);
      charlieSessionService = SecureSessionService(
        identityKeyService: charlieKeyService,
        getLocalNodeId: () => 'node-charlie',
      );
      charlieGroupService = GroupMessageService(
        packetTransport: charlieRouter,
        identityManager: _TestIdentityManager('node-charlie'),
        groupRepository: charlieGroupRepo,
        messageRepository: charlieMsgRepo,
        conversationRepository: charlieConvRepo,
        secureSessionService: charlieSessionService,
      );
      network.registerNode('node-charlie', charlieTransport);

      // Establish Pairwise E2E Secure Sessions between members
      // Alice <-> Bob
      final initAB = await aliceSessionService.createHandshakeInit('node-bob');
      final respAB = await bobSessionService.handleHandshakeInit(initAB);
      await aliceSessionService.handleHandshakeResponse(respAB);

      // Alice <-> Charlie
      final initAC = await aliceSessionService.createHandshakeInit(
        'node-charlie',
      );
      final respAC = await charlieSessionService.handleHandshakeInit(initAC);
      await aliceSessionService.handleHandshakeResponse(respAC);

      // Connect network topology: Alice <-> David <-> Bob, David <-> Charlie
      network.link('node-alice', 'node-david');
      network.link('node-david', 'node-bob');
      network.link('node-david', 'node-charlie');

      aliceRouter.addDirectNeighbor('node-david');
      bobRouter.addDirectNeighbor('node-david');
      charlieRouter.addDirectNeighbor('node-david');

      davidRouter.addDirectNeighbor('node-alice');
      davidRouter.addDirectNeighbor('node-bob');
      davidRouter.addDirectNeighbor('node-charlie');

      // Learn routes through David
      aliceRouter.routingTable.updateRoute(
        destinationNodeId: 'node-bob',
        nextHopPeerId: 'node-david',
        hopCount: 2,
      );
      aliceRouter.routingTable.updateRoute(
        destinationNodeId: 'node-charlie',
        nextHopPeerId: 'node-david',
        hopCount: 2,
      );
      bobRouter.routingTable.updateRoute(
        destinationNodeId: 'node-alice',
        nextHopPeerId: 'node-david',
        hopCount: 2,
      );
      charlieRouter.routingTable.updateRoute(
        destinationNodeId: 'node-alice',
        nextHopPeerId: 'node-david',
        hopCount: 2,
      );
    });

    tearDown(() async {
      aliceGroupService.dispose();
      aliceRouter.dispose();
      aliceTransport.dispose();
      await aliceDb.close();

      davidStoreForwardManager.dispose();
      davidRouter.dispose();
      davidTransport.dispose();
      await davidDb.close();

      bobGroupService.dispose();
      bobRouter.dispose();
      bobTransport.dispose();
      await bobDb.close();

      charlieGroupService.dispose();
      charlieRouter.dispose();
      charlieTransport.dispose();
      await charlieDb.close();
    });

    test(
      'Multi-hop encrypted group messaging: Alice sends to Bob and Charlie through relay David; '
      'David relays ciphertext without decrypting; Bob and Charlie receive, decrypt, and ACK',
      () async {
        // 1. Alice creates group 'Alpha Recon' with Bob and Charlie
        final bobMember = GroupMember(
          groupId: '',
          memberNodeId: 'node-bob',
          memberDisplayName: 'Bob',
          role: GroupMemberRole.member,
          joinedAt: DateTime.utc(2026, 11, 21),
        );
        final charlieMember = GroupMember(
          groupId: '',
          memberNodeId: 'node-charlie',
          memberDisplayName: 'Charlie',
          role: GroupMemberRole.member,
          joinedAt: DateTime.utc(2026, 11, 21),
        );

        final group = await aliceGroupService.createGroup(
          name: 'Alpha Recon',
          initialMembers: [bobMember, charlieMember],
        );

        // Allow membership packets to propagate across David
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify Bob and Charlie received group membership invite
        final bobGroup = await bobGroupRepo.getGroup(group.id);
        expect(bobGroup, isNotNull);
        expect(bobGroup!.name, equals('Alpha Recon'));

        final charlieGroup = await charlieGroupRepo.getGroup(group.id);
        expect(charlieGroup, isNotNull);
        expect(charlieGroup!.name, equals('Alpha Recon'));

        // 2. Alice sends a group message
        final bobIncomingFuture = bobGroupService.incomingGroupMessages.first;
        final charlieIncomingFuture =
            charlieGroupService.incomingGroupMessages.first;

        final sentMessage = await aliceGroupService.sendGroupMessage(
          groupId: group.id,
          content: 'Rendezvous at Sector 7',
        );

        final bobReceived = await bobIncomingFuture;
        final charlieReceived = await charlieIncomingFuture;

        expect(bobReceived.content, equals('Rendezvous at Sector 7'));
        expect(bobReceived.conversationId, equals('group-${group.id}'));
        expect(charlieReceived.content, equals('Rendezvous at Sector 7'));
        expect(charlieReceived.conversationId, equals('group-${group.id}'));

        // Wait for reverse-path ACKs to propagate back through David to Alice
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final memberStatuses = aliceGroupService.getMemberDeliveryStatuses(
          sentMessage.id,
        );
        expect(memberStatuses['node-bob'], equals(ChatMessageStatus.delivered));
        expect(
          memberStatuses['node-charlie'],
          equals(ChatMessageStatus.delivered),
        );

        final aliceStoredMsg = await aliceMsgRepo.getMessageById(
          sentMessage.id,
        );
        expect(aliceStoredMsg?.status, equals(ChatMessageStatus.delivered));
      },
    );

    test(
      'Delay-tolerant store-and-forward to offline member: Charlie disconnects; '
      'Alice sends group message; David queues Charlie packet; '
      'Charlie reconnects; David delivers queued packet; Charlie decrypts and ACKs',
      () async {
        // Disconnect Bob from David so David has no alternate flood branch
        network.unlink('node-david', 'node-bob');
        davidRouter.removePeer('node-bob');

        final now = DateTime.utc(2026, 11, 21);
        final group = await aliceGroupService.createGroup(
          name: 'Bravo Team',
          initialMembers: [
            GroupMember(
              groupId: '',
              memberNodeId: 'node-charlie',
              memberDisplayName: 'Charlie',
              role: GroupMemberRole.member,
              joinedAt: now,
            ),
          ],
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Disconnect Charlie from David
        network.unlink('node-david', 'node-charlie');
        davidRouter.removePeer('node-charlie');

        // Alice sends group message
        final sentMessage = await aliceGroupService.sendGroupMessage(
          groupId: group.id,
          content: 'Charlie report status',
        );

        // David should have stored Charlie's packet in store-and-forward queue
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final queuedPackets = await davidStoreForwardRepo.getPendingPackets();
        expect(queuedPackets, hasLength(1));
        expect(queuedPackets.first.recipientNodeId, equals('node-charlie'));

        // Charlie reconnects to David
        final charlieIncoming = charlieGroupService.incomingGroupMessages.first;
        network.link('node-david', 'node-charlie');
        davidRouter.addDirectNeighbor('node-charlie');

        // Charlie should receive the queued packet from David
        final charlieMsg = await charlieIncoming;
        expect(charlieMsg.content, equals('Charlie report status'));

        // Wait for reverse-path ACK from Charlie through David to Alice
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // David's queue should now be cleared
        final remainingQueued = await davidStoreForwardRepo.getPendingPackets();
        expect(remainingQueued, isEmpty);

        // Alice tracks Charlie as delivered
        final statuses = aliceGroupService.getMemberDeliveryStatuses(
          sentMessage.id,
        );
        expect(statuses['node-charlie'], equals(ChatMessageStatus.delivered));
      },
    );

    test('Removed member secrecy: Alice removes Charlie; Alice sends message; '
        'Bob receives it; Charlie never receives or decrypts packet', () async {
      final now = DateTime.utc(2026, 11, 21);
      final group = await aliceGroupService.createGroup(
        name: 'Classified Team',
        initialMembers: [
          GroupMember(
            groupId: '',
            memberNodeId: 'node-bob',
            memberDisplayName: 'Bob',
            role: GroupMemberRole.member,
            joinedAt: now,
          ),
          GroupMember(
            groupId: '',
            memberNodeId: 'node-charlie',
            memberDisplayName: 'Charlie',
            role: GroupMemberRole.member,
            joinedAt: now,
          ),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Alice removes Charlie
      await aliceGroupService.removeMember(
        groupId: group.id,
        memberNodeId: 'node-charlie',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Track Charlie incoming
      bool charlieReceivedAny = false;
      final sub = charlieGroupService.incomingGroupMessages.listen((_) {
        charlieReceivedAny = true;
      });

      // Alice sends message after Charlie removal
      final bobIncoming = bobGroupService.incomingGroupMessages.first;
      await aliceGroupService.sendGroupMessage(
        groupId: group.id,
        content: 'Confidential message after Charlie removal',
      );

      final bobReceived = await bobIncoming;
      expect(
        bobReceived.content,
        equals('Confidential message after Charlie removal'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(charlieReceivedAny, isFalse);

      final charlieHistory = await charlieMsgRepo.getMessagesForConversation(
        'group-${group.id}',
      );
      expect(
        charlieHistory.any((m) => m.content.contains('Confidential')),
        isFalse,
      );

      await sub.cancel();
    });
  });
}
