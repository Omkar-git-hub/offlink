import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/connection.dart';
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
import 'package:offlink/domain/lifecycle/app_lifecycle_coordinator.dart';
import 'package:offlink/domain/lifecycle/app_lifecycle_manager.dart';
import 'package:offlink/domain/lifecycle/background_service_contract.dart';
import 'package:offlink/domain/lifecycle/connection_recovery_coordinator.dart';
import 'package:offlink/domain/lifecycle/pending_message_recovery_service.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/mesh/seen_message_cache.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

import '../identity/fakes/fake_secure_key_storage.dart';

class _LoopbackTransport implements PacketTransport {
  _LoopbackTransport({required this.localNodeId});

  final String localNodeId;
  final StreamController<OfflinkPacket> _incoming =
      StreamController<OfflinkPacket>.broadcast();
  final Map<String, _LoopbackTransport> connectedPeers = {};
  bool dropPackets = false;

  @override
  Stream<OfflinkPacket> get incomingPackets => _incoming.stream;

  @override
  List<String> get connectedPeerIds => connectedPeers.keys.toList();

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    if (dropPackets) return;
    final target = connectedPeers[peerId];
    if (target != null) {
      target._incoming.add(packet);
    }
  }

  void connectTo(_LoopbackTransport peer) {
    connectedPeers[peer.localNodeId] = peer;
    peer.connectedPeers[localNodeId] = this;
  }

  void disconnectFrom(_LoopbackTransport peer) {
    connectedPeers.remove(peer.localNodeId);
    peer.connectedPeers.remove(localNodeId);
  }

  void dispose() {
    _incoming.close();
  }
}

class _FakeBleConnection implements BleConnection {
  _FakeBleConnection(this.transport, this.peerTransports);

  final _LoopbackTransport transport;
  final Map<String, _LoopbackTransport> peerTransports;
  final StreamController<BleConnectionState> _controller =
      StreamController<BleConnectionState>.broadcast();

  @override
  Stream<BleConnectionState> get connectionStates => _controller.stream;

  @override
  Future<void> connect(BlePeer peer) async {
    final target = peerTransports[peer.peerId];
    if (target != null) {
      transport.connectTo(target);
      _controller.add(BleConnectionState.connected);
    }
  }

  @override
  Future<void> disconnect(String peerId) async {
    final target = peerTransports[peerId];
    if (target != null) {
      transport.disconnectFrom(target);
      _controller.add(BleConnectionState.disconnected);
    }
  }

  void dispose() {
    _controller.close();
  }
}

class _FakeBackgroundService implements BackgroundServiceContract {
  bool isRunning = false;

  @override
  Future<bool> startService({String? title, String? message}) async {
    isRunning = true;
    return true;
  }

  @override
  Future<bool> stopService() async {
    isRunning = false;
    return true;
  }

  @override
  Future<bool> isServiceRunning() async => isRunning;
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lifecycle Resilience Integration (Multi-Hop Background & Recovery)', () {
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

    late AppLifecycleManager aliceLifecycleManager;
    late _FakeBackgroundService aliceBackgroundService;
    late ConnectionRecoveryCoordinator aliceConnectionRecovery;
    late PendingMessageRecoveryService alicePendingRecovery;
    late AppLifecycleCoordinator aliceCoordinator;
    late _FakeBleConnection aliceBleConnection;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      aliceTransport = _LoopbackTransport(localNodeId: 'node-alice');
      bobTransport = _LoopbackTransport(localNodeId: 'node-bob');
      charlieTransport = _LoopbackTransport(localNodeId: 'node-charlie');

      // Topologies: Alice <--> Bob <--> Charlie
      aliceTransport.connectTo(bobTransport);
      bobTransport.connectTo(charlieTransport);

      aliceBleConnection = _FakeBleConnection(aliceTransport, {
        'node-bob': bobTransport,
      });

      aliceRouter = MeshPacketRouter(
        transport: aliceTransport,
        getLocalNodeId: () => 'node-alice',
        seenCache: SeenMessageCache(entryTtl: const Duration(milliseconds: 30)),
      );
      bobRouter = MeshPacketRouter(
        transport: bobTransport,
        getLocalNodeId: () => 'node-bob',
        seenCache: SeenMessageCache(entryTtl: const Duration(milliseconds: 30)),
      );
      charlieRouter = MeshPacketRouter(
        transport: charlieTransport,
        getLocalNodeId: () => 'node-charlie',
        seenCache: SeenMessageCache(entryTtl: const Duration(milliseconds: 30)),
      );

      aliceRouter.addDirectNeighbor('node-bob');
      bobRouter.addDirectNeighbor('node-alice');
      bobRouter.addDirectNeighbor('node-charlie');
      charlieRouter.addDirectNeighbor('node-bob');

      // Databases
      aliceDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      aliceMsgRepo = DriftMessageRepository(aliceDb);
      aliceConvRepo = DriftConversationRepository(aliceDb);

      charlieDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      charlieMsgRepo = DriftMessageRepository(charlieDb);
      charlieConvRepo = DriftConversationRepository(charlieDb);

      // Identity Alice
      final aliceKeyService = IdentityKeyService(
        secureStorage: FakeSecureKeyStorage(),
      );
      final aliceKeyPair = await aliceKeyService.generateKeyPair();
      await aliceKeyService.storePrivateKey(aliceKeyPair.privateKey);
      final alicePubHex = (await aliceKeyService.exportPublicKey(
        aliceKeyPair.publicKey,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final aliceIdManager = IdentityManager(
        repository: _MemoryIdentityRepo(
          OfflinkIdentity(
            nodeId: 'node-alice',
            username: 'Alice',
            publicKey: alicePubHex,
            createdAt: DateTime.now().toUtc(),
          ),
        ),
        initializationService: IdentityInitializationService(
          nodeIdGenerator: NodeIdGenerator(),
          keyService: aliceKeyService,
        ),
        keyService: aliceKeyService,
      );
      await aliceIdManager.loadExistingIdentity();

      // Identity Charlie
      final charlieKeyService = IdentityKeyService(
        secureStorage: FakeSecureKeyStorage(),
      );
      final charlieKeyPair = await charlieKeyService.generateKeyPair();
      await charlieKeyService.storePrivateKey(charlieKeyPair.privateKey);
      final charliePubHex = (await charlieKeyService.exportPublicKey(
        charlieKeyPair.publicKey,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final charlieIdManager = IdentityManager(
        repository: _MemoryIdentityRepo(
          OfflinkIdentity(
            nodeId: 'node-charlie',
            username: 'Charlie',
            publicKey: charliePubHex,
            createdAt: DateTime.now().toUtc(),
          ),
        ),
        initializationService: IdentityInitializationService(
          nodeIdGenerator: NodeIdGenerator(),
          keyService: charlieKeyService,
        ),
        keyService: charlieKeyService,
      );
      await charlieIdManager.loadExistingIdentity();

      aliceSessionService = SecureSessionService(
        identityKeyService: aliceKeyService,
        getLocalNodeId: () => 'node-alice',
      );
      charlieSessionService = SecureSessionService(
        identityKeyService: charlieKeyService,
        getLocalNodeId: () => 'node-charlie',
      );

      // 2-way Handshake between Alice and Charlie
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

      // Lifecycle and Resilience Services for Alice
      aliceLifecycleManager = AppLifecycleManager();
      aliceBackgroundService = _FakeBackgroundService();
      aliceConnectionRecovery = ConnectionRecoveryCoordinator(
        connection: aliceBleConnection,
        initialDelay: const Duration(milliseconds: 30),
      );
      alicePendingRecovery = PendingMessageRecoveryService(
        messageService: aliceService,
        messageRepository: aliceMsgRepo,
        ackTimeout: const Duration(milliseconds: 50),
      );
      aliceCoordinator = AppLifecycleCoordinator(
        lifecycleManager: aliceLifecycleManager,
        backgroundService: aliceBackgroundService,
        connectionRecovery: aliceConnectionRecovery,
        pendingMessageRecovery: alicePendingRecovery,
      );
      aliceCoordinator.initialize();
    });

    tearDown(() async {
      aliceCoordinator.dispose();
      aliceBleConnection.dispose();
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
      'Alice backgrounded -> starts foreground service -> temporary link drop -> recovery -> pending message retry with same messageId delivers and updates status to delivered',
      () async {
        final charlieReceived = <ChatMessage>[];
        final charlieSub = charlieService.incomingMessages.listen(
          charlieReceived.add,
        );

        // 1. Move Alice to background: Foreground service must start
        aliceLifecycleManager.handleLifecycleChange(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);
        expect(aliceBackgroundService.isRunning, isTrue);

        // 2. Simulate link interruption: Bob's link to Charlie drops packets
        bobTransport.dropPackets = true;

        // Alice sends message to Charlie while link is interrupted
        final sentMessage = await aliceService.sendMessage(
          peerId: 'node-bob',
          recipientNodeId: 'node-charlie',
          content: 'Resilience test payload across backgrounded mesh',
        );

        await Future<void>.delayed(const Duration(milliseconds: 60));

        // Message is saved as 'sent' in Alice's repository
        var aliceMessages = await aliceMsgRepo.getMessagesForConversation(
          'node-charlie',
        );
        expect(aliceMessages, hasLength(1));
        expect(aliceMessages.first.id, equals(sentMessage.id));
        expect(aliceMessages.first.status, equals(ChatMessageStatus.sent));
        expect(charlieReceived, isEmpty); // Charlie hasn't received it yet

        // 3. Link recovers: Bob's link to Charlie restored
        bobTransport.dropPackets = false;

        // 4. Alice resumes to foreground: triggers pending message retry
        aliceLifecycleManager.handleLifecycleChange(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // 5. Verify Charlie received and decrypted the retried message
        expect(charlieReceived, hasLength(1));
        expect(
          charlieReceived.first.content,
          equals('Resilience test payload across backgrounded mesh'),
        );
        expect(charlieReceived.first.id, equals(sentMessage.id));

        // 6. Verify Charlie sent ACK back through Bob and Alice's status is updated to delivered
        await Future<void>.delayed(const Duration(milliseconds: 60));
        aliceMessages = await aliceMsgRepo.getMessagesForConversation(
          'node-charlie',
        );
        expect(aliceMessages.first.status, equals(ChatMessageStatus.delivered));

        // 7. Deduplication test: If another retry occurs, Charlie's SeenMessageCache drops duplicate
        final retried = await alicePendingRecovery.processPendingMessages();
        expect(retried, equals(0)); // Already delivered, not pending
        expect(
          charlieReceived,
          hasLength(1),
        ); // Still only 1 message delivered to Charlie

        await charlieSub.cancel();
      },
    );
  });
}
