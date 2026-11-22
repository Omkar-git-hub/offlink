import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/connection.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/lifecycle/connection_recovery_coordinator.dart';
import 'package:offlink/domain/lifecycle/pending_message_recovery_service.dart';
import 'package:offlink/domain/location/location_provider.dart';
import 'package:offlink/domain/location/location_service.dart';
import 'package:offlink/domain/location/position_data.dart';
import 'package:offlink/domain/mesh/mesh_packet_router.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/messaging/message_repository.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';
import 'package:offlink/domain/queue/queued_packet.dart';
import 'package:offlink/domain/queue/store_and_forward_manager.dart';
import 'package:offlink/domain/queue/store_and_forward_repository.dart';

// --- Mocks ---

class _FakeLocationProvider implements LocationProvider {
  PositionData position = PositionData(
    latitude: 37.7749,
    longitude: -122.4194,
    accuracy: 5.0,
    timestamp: DateTime.now().toUtc(),
  );

  @override
  Future<PositionData> getCurrentPosition({bool highAccuracy = false}) async =>
      position;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;
  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;
}

class _FakeTransport implements PacketTransport {
  final StreamController<OfflinkPacket> _incoming =
      StreamController<OfflinkPacket>.broadcast();
  final List<({String peerId, OfflinkPacket packet})> sent = [];
  List<String> connectedPeers = [];

  @override
  Stream<OfflinkPacket> get incomingPackets => _incoming.stream;
  @override
  List<String> get connectedPeerIds => connectedPeers;
  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    sent.add((peerId: peerId, packet: packet));
  }

  void dispose() => _incoming.close();
}

class _FakeIdentityManager implements IdentityManager {
  @override
  OfflinkIdentity? get currentIdentity => OfflinkIdentity(
    nodeId: 'node-local',
    username: 'LocalUser',
    publicKey:
        '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20',
    createdAt: DateTime.now(),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryMessageRepo implements MessageRepository {
  final List<ChatMessage> messages = [];

  @override
  Future<List<ChatMessage>> getPendingMessages({int limit = 50}) async {
    return messages
        .where((m) => m.isOutgoing && m.status == ChatMessageStatus.sent)
        .take(limit)
        .toList();
  }

  @override
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  }) async {
    messages.add(message);
  }

  @override
  Future<void> updateMessageStatus(String id, ChatMessageStatus status) async {
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      messages[idx] = messages[idx].copyWith(status: status);
    }
  }

  @override
  Future<int> pruneExpiredMessages({
    Duration maxAge = const Duration(hours: 24),
  }) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMessageService implements DirectMessageService {
  int retryCalls = 0;
  @override
  Future<void> retryMessage({
    required ChatMessage message,
    String? peerId,
  }) async {
    retryCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryStoreRepo implements StoreAndForwardRepository {
  final Map<String, QueuedPacket> packets = {};

  @override
  Future<void> enqueuePacket(QueuedPacket packet) async {
    packets[packet.id] = packet;
  }

  @override
  Future<int> getQueueSize() async => packets.length;
  @override
  Future<List<QueuedPacket>> getPendingPackets({
    String? recipientNodeId,
    int limit = 50,
  }) async => packets.values.toList();
  @override
  Future<void> removePacket(String id) async {
    packets.remove(id);
  }

  @override
  Future<int> pruneExpired({
    Duration maxAge = const Duration(hours: 24),
    int maxQueueSize = 200,
  }) async => 0;
  @override
  Future<void> updatePacketStatus(
    String id,
    QueuedPacketStatus status, {
    int? retryCount,
    DateTime? nextAttemptAt,
    int? ttl,
  }) async {
    final p = packets[id];
    if (p != null) {
      packets[id] = p.copyWith(status: status);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBleConnection implements BleConnection {
  final List<String> connectCalls = [];
  final List<DateTime> connectTimes = [];

  @override
  Stream<BleConnectionState> get connectionStates => const Stream.empty();
  @override
  Future<void> connect(BlePeer peer) async {
    connectCalls.add(peer.peerId);
    connectTimes.add(DateTime.now());
  }

  @override
  Future<void> disconnect(String peerId) async {}
}

void main() {
  group('Idle Timer Elimination & Power Optimization', () {
    test(
      'LocationService does not run periodic timer when 0 live sessions exist',
      () async {
        final transport = _FakeTransport();
        final service = LocationService(
          locationProvider: _FakeLocationProvider(),
          packetTransport: transport,
          identityManager: _FakeIdentityManager(),
        );

        expect(service.isPeriodicTimerRunning, isFalse);

        // Start a live location session
        await service.startLiveLocation(
          targetId: 'peer-alice',
          duration: const Duration(minutes: 15),
          isGroup: false,
        );

        expect(service.isPeriodicTimerRunning, isTrue);

        // Stop the session
        await service.stopLiveLocation('peer-alice');

        expect(service.isPeriodicTimerRunning, isFalse);

        service.dispose();
        transport.dispose();
      },
    );

    test(
      'PendingMessageRecoveryService suspends periodic timer when queue is empty',
      () async {
        final repo = _InMemoryMessageRepo();
        final msgService = _FakeMessageService();
        final recovery = PendingMessageRecoveryService(
          messageService: msgService,
          messageRepository: repo,
          checkInterval: const Duration(seconds: 10),
        );

        recovery.start();
        // Initially queue is empty, so timer should be suspended
        await recovery.processPendingMessages();
        expect(recovery.isPeriodicTimerRunning, isFalse);

        // When message is queued, timer can be ensured running
        recovery.notifyPendingMessageQueued();
        expect(recovery.isPeriodicTimerRunning, isTrue);

        // After queue is drained
        await recovery.processPendingMessages();
        expect(recovery.isPeriodicTimerRunning, isFalse);

        recovery.dispose();
      },
    );

    test(
      'StoreAndForwardManager suspends timer when store-and-forward queue is empty',
      () async {
        final storeRepo = _InMemoryStoreRepo();
        final transport = _FakeTransport();
        final router = MeshPacketRouter(
          transport: transport,
          getLocalNodeId: () => 'node-local',
        );

        final manager = StoreAndForwardManager(
          repository: storeRepo,
          transport: transport,
          routingTable: router.routingTable,
          getLocalNodeId: () => 'node-local',
          getConnectedPeerIds: () => transport.connectedPeerIds,
        );

        manager.start();
        await Future<void>.delayed(Duration.zero);
        expect(manager.isPeriodicTimerRunning, isFalse);

        // Enqueue an eligible in-transit packet
        final packet = OfflinkPacket(
          messageId: 'pkt-transit-1',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-bob',
          messageType: OfflinkMessageType.encrypted,
          payload: 'cipher',
          timestamp: DateTime.now().toUtc(),
          ttl: 4,
        );
        await manager.enqueueInTransitPacket(packet);
        expect(manager.isPeriodicTimerRunning, isTrue);

        // ACK removes the stored packet
        await manager.onAckReceived('pkt-transit-1');
        expect(manager.isPeriodicTimerRunning, isFalse);

        manager.dispose();
        router.dispose();
        transport.dispose();
      },
    );

    test(
      'ConnectionRecoveryCoordinator caps max attempts in background mode',
      () async {
        final connection = _FakeBleConnection();
        final coordinator = ConnectionRecoveryCoordinator(
          connection: connection,
          maxAttempts: 5,
          backgroundMaxAttempts: 3,
          initialDelay: const Duration(milliseconds: 10),
          backgroundInitialDelay: const Duration(milliseconds: 10),
        );

        coordinator.setBackgroundState(true);
        expect(coordinator.isBackgrounded, isTrue);

        final testPeer = BlePeer(
          peerId: 'peer-drop-1',
          displayName: 'Peer 1',
          signalStrength: -70,
        );
        coordinator.trackPeer(testPeer);

        // Schedule reconnect past background max attempts
        coordinator.scheduleReconnect(testPeer); // attempt 1
        coordinator.scheduleReconnect(testPeer); // attempt 2
        coordinator.scheduleReconnect(testPeer); // attempt 3

        final events = <RecoveryEvent>[];
        coordinator.recoveryEvents.listen(events.add);
        coordinator.scheduleReconnect(
          testPeer,
        ); // attempt 4 -> exceeds backgroundMaxAttempts (3)

        await Future<void>.delayed(Duration.zero);
        expect(
          events.any((e) => e.type == RecoveryEventType.maxAttemptsReached),
          isTrue,
        );

        coordinator.dispose();
      },
    );

    test(
      'MeshPacketRouter does not flood packets back to their sender node',
      () async {
        final transport = _FakeTransport();
        transport.connectedPeers = ['node-alice', 'node-charlie'];

        final router = MeshPacketRouter(
          transport: transport,
          getLocalNodeId: () => 'node-relay',
        );

        // Packet originating from node-alice destined for node-unknown (triggers flood)
        final packet = OfflinkPacket(
          messageId: 'flood-msg-1',
          senderNodeId: 'node-alice',
          recipientNodeId: 'node-unknown',
          messageType: OfflinkMessageType.text,
          payload: 'Flood test',
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
        );

        await router.onPacketReceived(packet, fromPeerId: 'node-alice');

        // Check where packet was forwarded
        expect(transport.sent.length, equals(1));
        expect(transport.sent.first.peerId, equals('node-charlie'));
        // Never echoed back to node-alice
        expect(transport.sent.any((s) => s.peerId == 'node-alice'), isFalse);

        router.dispose();
        transport.dispose();
      },
    );
  });
}
