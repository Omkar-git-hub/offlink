import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/encrypted_payload.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_group_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/drift_store_and_forward_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/location/location_payload.dart';
import 'package:offlink/domain/location/location_provider.dart';
import 'package:offlink/domain/location/location_service.dart';
import 'package:offlink/domain/location/position_data.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/mesh/seen_message_cache.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
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

class _StaticLocationProvider implements LocationProvider {
  _StaticLocationProvider(this.position);
  PositionData position;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;
  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;
  @override
  Future<PositionData> getCurrentPosition({bool highAccuracy = false}) async =>
      position;
}

void main() {
  group('Location Mesh & Store-and-Forward Integration (Multi-Hop Simulation)', () {
    late _SimulatedMeshNetwork network;

    // Topology:
    // Alice <--> Bob (Relay) <--> Charlie
    late _SimulatedNodeTransport aliceTransport;
    late _SimulatedNodeTransport bobTransport;
    late _SimulatedNodeTransport charlieTransport;

    late MeshPacketRouter aliceRouter;
    late MeshPacketRouter bobRouter;
    late MeshPacketRouter charlieRouter;

    late OfflinkDatabase aliceDb;
    late OfflinkDatabase bobDb;
    late OfflinkDatabase charlieDb;

    late DriftMessageRepository aliceMsgRepo;
    late DriftConversationRepository aliceConvRepo;
    late DriftGroupRepository aliceGroupRepo;

    late DriftMessageRepository charlieMsgRepo;
    late DriftConversationRepository charlieConvRepo;
    late DriftGroupRepository charlieGroupRepo;

    late DriftStoreAndForwardRepository bobStoreRepo;
    late StoreAndForwardManager bobStoreManager;

    late IdentityKeyService aliceKeyService;
    late IdentityKeyService charlieKeyService;

    late SecureSessionService aliceSecureSession;
    late SecureSessionService charlieSecureSession;

    late LocationService aliceLocationService;
    late LocationService charlieLocationService;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      network = _SimulatedMeshNetwork();

      // Alice
      aliceDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      aliceMsgRepo = DriftMessageRepository(aliceDb);
      aliceConvRepo = DriftConversationRepository(aliceDb);
      aliceGroupRepo = DriftGroupRepository(aliceDb);
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
      aliceSecureSession = SecureSessionService(
        identityKeyService: aliceKeyService,
        getLocalNodeId: () => 'node-alice',
      );
      network.registerNode('node-alice', aliceTransport);

      // Bob (Relay)
      bobDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      bobStoreRepo = DriftStoreAndForwardRepository(bobDb);
      bobTransport = _SimulatedNodeTransport(
        nodeId: 'node-bob',
        network: network,
      );
      bobRouter = MeshPacketRouter(
        transport: bobTransport,
        getLocalNodeId: () => 'node-bob',
        seenCache: SeenMessageCache(entryTtl: const Duration(seconds: 3)),
      );
      bobStoreManager = StoreAndForwardManager(
        repository: bobStoreRepo,
        transport: bobTransport,
        routingTable: bobRouter.routingTable,
        getLocalNodeId: () => 'node-bob',
        getConnectedPeerIds: () => bobTransport.connectedPeerIds,
        initialBackoff: Duration.zero,
      );
      bobRouter.storeAndForwardManager = bobStoreManager;
      network.registerNode('node-bob', bobTransport);

      // Charlie
      charlieDb = OfflinkDatabase.forTesting(NativeDatabase.memory());
      charlieMsgRepo = DriftMessageRepository(charlieDb);
      charlieConvRepo = DriftConversationRepository(charlieDb);
      charlieGroupRepo = DriftGroupRepository(charlieDb);
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
      charlieSecureSession = SecureSessionService(
        identityKeyService: charlieKeyService,
        getLocalNodeId: () => 'node-charlie',
      );
      network.registerNode('node-charlie', charlieTransport);

      aliceLocationService = LocationService(
        locationProvider: _StaticLocationProvider(
          PositionData(
            latitude: 37.7749,
            longitude: -122.4194,
            accuracy: 10.0,
            timestamp: DateTime.now().toUtc(),
          ),
        ),
        packetTransport: aliceRouter,
        identityManager: _TestIdentityManager('node-alice'),
        secureSessionService: aliceSecureSession,
        messageRepository: aliceMsgRepo,
        conversationRepository: aliceConvRepo,
        groupRepository: aliceGroupRepo,
      );

      charlieLocationService = LocationService(
        locationProvider: _StaticLocationProvider(
          PositionData(
            latitude: 37.7750,
            longitude: -122.4190,
            accuracy: 10.0,
            timestamp: DateTime.now().toUtc(),
          ),
        ),
        packetTransport: charlieRouter,
        identityManager: _TestIdentityManager('node-charlie'),
        secureSessionService: charlieSecureSession,
        messageRepository: charlieMsgRepo,
        conversationRepository: charlieConvRepo,
        groupRepository: charlieGroupRepo,
      );
    });

    tearDown(() async {
      aliceLocationService.dispose();
      charlieLocationService.dispose();
      aliceRouter.dispose();
      bobStoreManager.dispose();
      bobRouter.dispose();
      charlieRouter.dispose();
      aliceTransport.dispose();
      bobTransport.dispose();
      charlieTransport.dispose();
      await aliceDb.close();
      await bobDb.close();
      await charlieDb.close();
    });

    Future<void> establishSessionAliceAndCharlie() async {
      final init = await aliceSecureSession.createHandshakeInit('node-charlie');
      final resp = await charlieSecureSession.handleHandshakeInit(init);
      await aliceSecureSession.handleHandshakeResponse(resp);
    }

    test(
      'Alice sends encrypted location snapshot to Charlie via relay Bob; '
      'Bob forwards ciphertext intact without decrypting; '
      'Charlie decrypts and emits ACK which updates Alice status to delivered',
      () async {
        // Connect mesh links: Alice <-> Bob <-> Charlie
        network.link('node-alice', 'node-bob');
        network.link('node-bob', 'node-charlie');

        aliceRouter.addDirectNeighbor('node-bob');
        bobRouter.addDirectNeighbor('node-alice');
        bobRouter.addDirectNeighbor('node-charlie');
        charlieRouter.addDirectNeighbor('node-bob');

        // Multi-hop routes
        aliceRouter.routingTable.updateRoute(
          destinationNodeId: 'node-charlie',
          nextHopPeerId: 'node-bob',
          hopCount: 2,
        );
        charlieRouter.routingTable.updateRoute(
          destinationNodeId: 'node-alice',
          nextHopPeerId: 'node-bob',
          hopCount: 2,
        );

        // Perform mutual authenticated session handshake
        await establishSessionAliceAndCharlie();
        expect(aliceSecureSession.hasSession('node-charlie'), isTrue);
        expect(charlieSecureSession.hasSession('node-alice'), isTrue);

        // Intercept packets on Bob to verify Bob relays ciphertext only
        final bobObservedPackets = <OfflinkPacket>[];
        final sub = bobTransport.incomingPackets.listen(bobObservedPackets.add);

        // Alice sends one-time location to Charlie
        final chatMsg = await aliceLocationService.sendOneTimeLocation(
          targetId: 'node-charlie',
          isGroup: false,
          peerId: 'node-bob',
        );

        // Wait for multi-hop propagation and reverse-path ACK
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await sub.cancel();

        // 1. Verify Bob observed ciphertext and could NOT decrypt it
        final relayedLocationPackets = bobObservedPackets.where(
          (p) => p.messageType == OfflinkMessageType.location,
        );
        expect(relayedLocationPackets.isNotEmpty, isTrue);

        final relayedPacket = relayedLocationPackets.first;
        expect(relayedPacket.senderNodeId, 'node-alice');
        expect(relayedPacket.recipientNodeId, 'node-charlie');

        // Verify Bob sees only EncryptedPayload ciphertext
        expect(
          () => EncryptedPayload.decode(relayedPacket.payload),
          returnsNormally,
        );
        // Bob cannot parse this as plaintext LocationPayload
        expect(
          () => LocationPayload.decode(relayedPacket.payload),
          throwsFormatException,
        );

        // 2. Verify Charlie received and decrypted the location snapshot
        final charlieSaved = await charlieMsgRepo.getMessageById(chatMsg.id);
        expect(charlieSaved, isNotNull);
        expect(
          LocationPayload.isLocationMessage(charlieSaved!.content),
          isTrue,
        );

        final charliePayload = LocationPayload.decode(charlieSaved.content);
        expect(charliePayload.latitude, 37.7749);
        expect(charliePayload.longitude, -122.4194);
        expect(charliePayload.senderNodeId, 'node-alice');

        // 3. Verify Alice received ACK and updated status to delivered
        final aliceSaved = await aliceMsgRepo.getMessageById(chatMsg.id);
        expect(aliceSaved?.status, ChatMessageStatus.delivered);
      },
    );

    test(
      'Store-and-Forward DTN: Alice sends location to Charlie while Charlie is offline; '
      'Bob queues packet; Charlie connects later; Bob flushes packet; Charlie decrypts',
      () async {
        // Alice connected to Bob; Charlie is OFFLINE
        network.link('node-alice', 'node-bob');
        aliceRouter.addDirectNeighbor('node-bob');
        bobRouter.addDirectNeighbor('node-alice');

        aliceRouter.routingTable.updateRoute(
          destinationNodeId: 'node-charlie',
          nextHopPeerId: 'node-bob',
          hopCount: 2,
        );

        await establishSessionAliceAndCharlie();

        // Alice sends location snapshot to offline Charlie
        final chatMsg = await aliceLocationService.sendOneTimeLocation(
          targetId: 'node-charlie',
          isGroup: false,
          peerId: 'node-bob',
        );

        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Bob has no route to Charlie, so Bob queues the packet in Store-and-Forward
        final queuedPackets = await bobStoreRepo.getPendingPackets(
          recipientNodeId: 'node-charlie',
        );
        expect(queuedPackets.isNotEmpty, isTrue);
        expect(queuedPackets.first.messageType, OfflinkMessageType.location);

        // Bob holds opaque ciphertext
        expect(queuedPackets.first.payload, contains('ciphertext'));
        expect(
          () => LocationPayload.decode(queuedPackets.first.payload),
          throwsFormatException,
        );

        // Charlie comes online and connects to Bob
        network.link('node-bob', 'node-charlie');
        bobRouter.addDirectNeighbor('node-charlie');
        charlieRouter.addDirectNeighbor('node-bob');

        // Wait for store-and-forward automatic opportunistic flush upon connection
        await Future<void>.delayed(const Duration(milliseconds: 250));

        // Verify Charlie decrypted and persisted the stored location message
        final charlieSaved = await charlieMsgRepo.getMessageById(chatMsg.id);
        expect(charlieSaved, isNotNull);
        final charliePayload = LocationPayload.decode(charlieSaved!.content);
        expect(charliePayload.latitude, 37.7749);
        expect(charliePayload.longitude, -122.4194);
      },
    );
  });
}
