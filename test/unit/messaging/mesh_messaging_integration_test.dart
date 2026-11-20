import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

import '../identity/fakes/fake_secure_key_storage.dart';

class _LoopbackTransport implements PacketTransport {
  _LoopbackTransport({required this.localNodeId});

  final String localNodeId;
  final StreamController<OfflinkPacket> _incoming =
      StreamController<OfflinkPacket>.broadcast();
  final Map<String, _LoopbackTransport> connectedPeers = {};

  @override
  Stream<OfflinkPacket> get incomingPackets => _incoming.stream;

  @override
  List<String> get connectedPeerIds => connectedPeers.keys.toList();

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    final target = connectedPeers[peerId];
    if (target != null) {
      target._incoming.add(packet);
    }
  }

  void connectTo(_LoopbackTransport peer) {
    connectedPeers[peer.localNodeId] = peer;
    peer.connectedPeers[localNodeId] = this;
  }

  void dispose() {
    _incoming.close();
  }
}

class _MemoryIdentityRepo implements IdentityRepository {
  _MemoryIdentityRepo(this.identity);
  OfflinkIdentity? identity;

  @override
  Future<OfflinkIdentity?> loadIdentity() async => identity;
  @override
  Future<bool> hasIdentity() async => identity != null;
  @override
  Future<void> saveIdentity(OfflinkIdentity id) async => identity = id;
  @override
  Future<void> updateUsername(String u) async =>
      identity = identity?.copyWith(username: u);
  @override
  Future<void> clearIdentity() async => identity = null;
}

void main() {
  group('Mesh Messaging Integration (3-Node Multi-Hop Simulation)', () {
    // Topologies:
    // Alice <--> Bob (Relay) <--> Charlie
    late _LoopbackTransport aliceTransport;
    late _LoopbackTransport bobTransport;
    late _LoopbackTransport charlieTransport;

    late MeshPacketRouter aliceRouter;
    late MeshPacketRouter bobRouter;
    late MeshPacketRouter charlieRouter;

    late OfflinkDatabase aliceDb;
    late DriftMessageRepository aliceMsgRepo;
    late DriftConversationRepository aliceConvRepo;

    late OfflinkDatabase charlieDb;
    late DriftMessageRepository charlieMsgRepo;
    late DriftConversationRepository charlieConvRepo;

    late DirectMessageService aliceService;
    late DirectMessageService charlieService;

    late SecureSessionService aliceSessionService;
    late SecureSessionService charlieSessionService;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      aliceTransport = _LoopbackTransport(localNodeId: 'node-alice');
      bobTransport = _LoopbackTransport(localNodeId: 'node-bob');
      charlieTransport = _LoopbackTransport(localNodeId: 'node-charlie');

      // Connect Alice to Bob, and Bob to Charlie (Alice and Charlie are NOT directly connected)
      aliceTransport.connectTo(bobTransport);
      bobTransport.connectTo(charlieTransport);

      aliceRouter = MeshPacketRouter(
        transport: aliceTransport,
        getLocalNodeId: () => 'node-alice',
      );
      bobRouter = MeshPacketRouter(
        transport: bobTransport,
        getLocalNodeId: () => 'node-bob',
      );
      charlieRouter = MeshPacketRouter(
        transport: charlieTransport,
        getLocalNodeId: () => 'node-charlie',
      );

      // Tell Alice that Bob is neighbor, Bob that Alice & Charlie are neighbors, Charlie that Bob is neighbor
      aliceRouter.addDirectNeighbor('node-bob');
      bobRouter.addDirectNeighbor('node-alice');
      bobRouter.addDirectNeighbor('node-charlie');
      charlieRouter.addDirectNeighbor('node-bob');

      // Database setups
      aliceDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      aliceMsgRepo = DriftMessageRepository(aliceDb);
      aliceConvRepo = DriftConversationRepository(aliceDb);

      charlieDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      charlieMsgRepo = DriftMessageRepository(charlieDb);
      charlieConvRepo = DriftConversationRepository(charlieDb);

      // Identity setups
      final aliceKeyService = IdentityKeyService(
        secureStorage: FakeSecureKeyStorage(),
      );
      final aliceKeyPair = await aliceKeyService.generateKeyPair();
      await aliceKeyService.storePrivateKey(aliceKeyPair.privateKey);
      final alicePubHex = (await aliceKeyService.exportPublicKey(
        aliceKeyPair.publicKey,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final aliceIdentity = OfflinkIdentity(
        nodeId: 'node-alice',
        username: 'Alice',
        publicKey: alicePubHex,
        createdAt: DateTime.now().toUtc(),
      );
      final aliceIdManager = IdentityManager(
        repository: _MemoryIdentityRepo(aliceIdentity),
        initializationService: IdentityInitializationService(
          nodeIdGenerator: NodeIdGenerator(),
          keyService: aliceKeyService,
        ),
        keyService: aliceKeyService,
      );
      await aliceIdManager.loadExistingIdentity();

      final charlieKeyService = IdentityKeyService(
        secureStorage: FakeSecureKeyStorage(),
      );
      final charlieKeyPair = await charlieKeyService.generateKeyPair();
      await charlieKeyService.storePrivateKey(charlieKeyPair.privateKey);
      final charliePubHex = (await charlieKeyService.exportPublicKey(
        charlieKeyPair.publicKey,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final charlieIdentity = OfflinkIdentity(
        nodeId: 'node-charlie',
        username: 'Charlie',
        publicKey: charliePubHex,
        createdAt: DateTime.now().toUtc(),
      );
      final charlieIdManager = IdentityManager(
        repository: _MemoryIdentityRepo(charlieIdentity),
        initializationService: IdentityInitializationService(
          nodeIdGenerator: NodeIdGenerator(),
          keyService: charlieKeyService,
        ),
        keyService: charlieKeyService,
      );
      await charlieIdManager.loadExistingIdentity();

      // Secure session services (Alice and Charlie only, Bob does not participate in encryption)
      aliceSessionService = SecureSessionService(
        identityKeyService: aliceKeyService,
        getLocalNodeId: () => 'node-alice',
      );
      charlieSessionService = SecureSessionService(
        identityKeyService: charlieKeyService,
        getLocalNodeId: () => 'node-charlie',
      );

      // Perform handshake between Alice and Charlie across the multi-hop network
      final handshakeInit = await aliceSessionService.createHandshakeInit(
        'node-charlie',
      );
      final handshakeResponse = await charlieSessionService.handleHandshakeInit(
        handshakeInit,
      );
      await aliceSessionService.handleHandshakeResponse(handshakeResponse);

      aliceService = DirectMessageService(
        packetTransport: aliceRouter,
        identityManager: aliceIdManager,
        messageRepository: aliceMsgRepo,
        conversationRepository: aliceConvRepo,
        secureSessionService: aliceSessionService,
      );

      charlieService = DirectMessageService(
        packetTransport: charlieRouter,
        identityManager: charlieIdManager,
        messageRepository: charlieMsgRepo,
        conversationRepository: charlieConvRepo,
        secureSessionService: charlieSessionService,
      );
    });

    tearDown(() async {
      aliceService.dispose();
      charlieService.dispose();
      aliceRouter.dispose();
      bobRouter.dispose();
      charlieRouter.dispose();
      aliceTransport.dispose();
      bobTransport.dispose();
      charlieTransport.dispose();
      await aliceDb.close();
      await charlieDb.close();
    });

    test(
      'Alice sends encrypted message to Charlie via relay Bob; Bob forwards ciphertext intact without decrypting; Charlie receives and automatically sends ACK which updates Alice status to delivered',
      () async {
        final charlieReceivedMessages = <ChatMessage>[];
        final charlieSub = charlieService.incomingMessages.listen(
          charlieReceivedMessages.add,
        );

        final bobForwardedPackets = <OfflinkPacket>[];
        final bobSub = bobRouter.forwardedPackets.listen(
          bobForwardedPackets.add,
        );

        // Alice sends message to Charlie (routed via Bob)
        final sentMessage = await aliceService.sendMessage(
          peerId: 'node-bob', // immediate next hop or target peer
          recipientNodeId: 'node-charlie',
          content: 'Top secret multi-hop message!',
        );

        // Allow async events to circulate through mesh
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 1. Verify Bob forwarded the packet without decrypting or touching the ciphertext payload
        expect(bobForwardedPackets, isNotEmpty);
        final forwardedToCharlie = bobForwardedPackets.firstWhere(
          (p) => p.recipientNodeId == 'node-charlie',
        );
        expect(
          forwardedToCharlie.ttl,
          equals(sentMessage.isOutgoing ? 2 : 3),
        ); // TTL decremented
        expect(
          forwardedToCharlie.messageType,
          equals(OfflinkMessageType.encrypted),
        );
        // Bob only saw ciphertext, not plaintext:
        expect(forwardedToCharlie.payload.contains('Top secret'), isFalse);

        // 2. Verify Charlie received and decrypted the plaintext message
        expect(charlieReceivedMessages, hasLength(1));
        expect(
          charlieReceivedMessages.first.content,
          equals('Top secret multi-hop message!'),
        );
        expect(
          charlieReceivedMessages.first.senderNodeId,
          equals('node-alice'),
        );

        // 3. Verify Charlie automatically saved the message in his local database
        final charlieDbMessages = await charlieMsgRepo
            .getMessagesForConversation('node-alice');
        expect(charlieDbMessages, hasLength(1));
        expect(
          charlieDbMessages.first.content,
          equals('Top secret multi-hop message!'),
        );

        // 4. Verify Charlie's automatic ACK traveled back through Bob to Alice
        final bobAckForwards = bobForwardedPackets
            .where((p) => p.messageType == OfflinkMessageType.acknowledgement)
            .toList();
        expect(bobAckForwards, isNotEmpty);

        // 5. Verify Alice's message status in database is updated to delivered
        final aliceDbMessages = await aliceMsgRepo.getMessagesForConversation(
          'node-charlie',
        );
        expect(aliceDbMessages, hasLength(1));
        expect(aliceDbMessages.first.id, equals(sentMessage.id));
        expect(
          aliceDbMessages.first.status,
          equals(ChatMessageStatus.delivered),
        );

        await charlieSub.cancel();
        await bobSub.cancel();
      },
    );
  });
}
