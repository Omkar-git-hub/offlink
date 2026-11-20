import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/drift_store_and_forward_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/mesh/seen_message_cache.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
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
  group('Store-and-Forward Integration (3-Node DTN Simulation)', () {
    late _SimulatedMeshNetwork network;

    // Alice
    late OfflinkDatabase aliceDb;
    late DriftMessageRepository aliceMsgRepo;
    late _SimulatedNodeTransport aliceTransport;
    late MeshPacketRouter aliceRouter;
    late IdentityKeyService aliceKeyService;
    late SecureSessionService aliceSessionService;
    late DirectMessageService aliceMsgService;

    // Bob (Relay / Data Mule)
    late OfflinkDatabase bobDb;
    late DriftStoreAndForwardRepository bobStoreForwardRepo;
    late _SimulatedNodeTransport bobTransport;
    late MeshPacketRouter bobRouter;
    late StoreAndForwardManager bobStoreForwardManager;

    // Charlie (Eventual Recipient)
    late OfflinkDatabase charlieDb;
    late DriftMessageRepository charlieMsgRepo;
    late _SimulatedNodeTransport charlieTransport;
    late MeshPacketRouter charlieRouter;
    late IdentityKeyService charlieKeyService;
    late SecureSessionService charlieSessionService;
    late DirectMessageService charlieMsgService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      network = _SimulatedMeshNetwork();

      // Setup Alice
      aliceDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      aliceMsgRepo = DriftMessageRepository(aliceDb);
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
      aliceMsgService = DirectMessageService(
        packetTransport: aliceRouter,
        identityManager: _TestIdentityManager('node-alice'),
        messageRepository: aliceMsgRepo,
        conversationRepository: DriftConversationRepository(aliceDb),
        secureSessionService: aliceSessionService,
      );
      network.registerNode('node-alice', aliceTransport);

      // Setup Bob (Relay)
      bobDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      bobStoreForwardRepo = DriftStoreAndForwardRepository(bobDb);
      bobTransport = _SimulatedNodeTransport(
        nodeId: 'node-bob',
        network: network,
      );
      bobRouter = MeshPacketRouter(
        transport: bobTransport,
        getLocalNodeId: () => 'node-bob',
        seenCache: SeenMessageCache(entryTtl: const Duration(seconds: 3)),
      );
      bobStoreForwardManager = StoreAndForwardManager(
        repository: bobStoreForwardRepo,
        transport: bobTransport,
        routingTable: bobRouter.routingTable,
        getLocalNodeId: () => 'node-bob',
        getConnectedPeerIds: () => bobTransport.connectedPeerIds,
        initialBackoff: Duration.zero,
      );
      bobRouter.storeAndForwardManager = bobStoreForwardManager;
      network.registerNode('node-bob', bobTransport);

      // Setup Charlie
      charlieDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      charlieMsgRepo = DriftMessageRepository(charlieDb);
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
      charlieMsgService = DirectMessageService(
        packetTransport: charlieRouter,
        identityManager: _TestIdentityManager('node-charlie'),
        messageRepository: charlieMsgRepo,
        conversationRepository: DriftConversationRepository(charlieDb),
        secureSessionService: charlieSessionService,
      );
      network.registerNode('node-charlie', charlieTransport);

      // Pre-establish E2E key exchange between Alice and Charlie
      final init = await aliceSessionService.createHandshakeInit(
        'node-charlie',
      );
      final resp = await charlieSessionService.handleHandshakeInit(init);
      await aliceSessionService.handleHandshakeResponse(resp);
    });

    tearDown(() async {
      aliceMsgService.dispose();
      aliceRouter.dispose();
      aliceTransport.dispose();
      await aliceDb.close();

      bobStoreForwardManager.dispose();
      bobRouter.dispose();
      bobTransport.dispose();
      await bobDb.close();

      charlieMsgService.dispose();
      charlieRouter.dispose();
      charlieTransport.dispose();
      await charlieDb.close();
    });

    test(
      'Alice sends message to Charlie when Charlie is offline; Bob stores packet; '
      'Alice disconnects; Charlie connects to Bob; Bob forwards stored packet; '
      'Charlie decrypts and ACKs; Bob purges queue; Alice receives ACK upon reconnect',
      () async {
        // 1. Initial topology: Alice connected to Bob. Charlie is offline.
        network.link('node-alice', 'node-bob');
        aliceRouter.addDirectNeighbor('node-bob');
        bobRouter.addDirectNeighbor('node-alice');

        // Charlie receives stream
        final charlieReceived = <ChatMessage>[];
        final charlieSub = charlieMsgService.incomingMessages.listen(
          charlieReceived.add,
        );

        // 2. Alice sends end-to-end encrypted message to Charlie via Bob
        final sentMessage = await aliceMsgService.sendMessage(
          peerId: 'node-bob',
          recipientNodeId: 'node-charlie',
          content: 'Meet at coordinates X when ready',
        );

        expect(sentMessage.id, startsWith('msg-'));
        expect(sentMessage.status, equals(ChatMessageStatus.sent));

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // 3. Bob received the packet for Charlie, but has NO route or link to Charlie:
        // Bob's store-and-forward queue must contain 1 stored packet!
        expect(await bobStoreForwardRepo.getQueueSize(), equals(1));
        final storedPacket = await bobStoreForwardRepo.getPacket(
          sentMessage.id,
        );
        expect(storedPacket, isNotNull);
        expect(storedPacket!.recipientNodeId, equals('node-charlie'));
        expect(storedPacket.senderNodeId, equals('node-alice'));

        // RELAY PRIVACY VERIFICATION: Bob cannot decrypt and holds only opaque ciphertext
        expect(storedPacket.payload, isNot(contains('Meet at coordinates X')));
        expect(storedPacket.payload, contains('ciphertext'));

        // 4. Alice disconnects from Bob (out of range)
        network.unlink('node-alice', 'node-bob');
        bobRouter.removePeer('node-alice');
        aliceRouter.removePeer('node-bob');

        // 5. Charlie walks into range of Bob: link established between Bob and Charlie
        network.link('node-bob', 'node-charlie');
        charlieRouter.addDirectNeighbor('node-bob');
        bobRouter.addDirectNeighbor('node-charlie');

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 6. Verification at Charlie:
        // Charlie received and decrypted Alice's message!
        expect(charlieReceived, hasLength(1));
        expect(charlieReceived.first.id, equals(sentMessage.id));
        expect(
          charlieReceived.first.content,
          equals('Meet at coordinates X when ready'),
        );

        final charliePersisted = await charlieMsgRepo.getMessageById(
          sentMessage.id,
        );
        expect(charliePersisted, isNotNull);
        expect(
          charliePersisted!.content,
          equals('Meet at coordinates X when ready'),
        );

        // 7. Verification at Bob:
        // Charlie sent back an ACK. Bob processed the ACK:
        // Bob's store-and-forward queue has purged the original message packet!
        expect(await bobStoreForwardRepo.getPacket(sentMessage.id), isNull);

        // Bob stored Charlie's reverse-path ACK packet to deliver to Alice when she reconnects
        final pendingAcks = await bobStoreForwardRepo.getPendingPackets(
          recipientNodeId: 'node-alice',
        );
        expect(pendingAcks, hasLength(1));
        expect(
          pendingAcks.first.messageType,
          equals(OfflinkMessageType.acknowledgement),
        );
        expect(pendingAcks.first.payload, equals(sentMessage.id));

        // 8. Alice reconnects to Bob (data mule rendezvous):
        // Bob automatically flushes the stored ACK packet to Alice!
        network.link('node-alice', 'node-bob');
        aliceRouter.addDirectNeighbor('node-bob');
        bobRouter.addDirectNeighbor('node-alice');

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 9. Alice received the delivery ACK: status updated to delivered in SQLite
        final alicePersisted = await aliceMsgRepo.getMessageById(
          sentMessage.id,
        );
        expect(alicePersisted!.status, equals(ChatMessageStatus.delivered));

        await charlieSub.cancel();
      },
    );
  });
}
