import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_group_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/group/group.dart';
import 'package:offlink/domain/group/group_member.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/location/location_payload.dart';
import 'package:offlink/domain/location/location_provider.dart';
import 'package:offlink/domain/location/location_service.dart';
import 'package:offlink/domain/location/position_data.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

class FakeLocationProvider implements LocationProvider {
  bool serviceEnabled = true;
  LocationPermissionStatus permissionStatus = LocationPermissionStatus.granted;
  PositionData currentPosition = PositionData(
    latitude: 37.7749,
    longitude: -122.4194,
    accuracy: 10.0,
    timestamp: DateTime.utc(2026, 11, 21, 10, 0),
  );

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permissionStatus;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      permissionStatus;

  @override
  Future<PositionData> getCurrentPosition({bool highAccuracy = false}) async {
    if (!serviceEnabled) {
      throw StateError('Location services disabled.');
    }
    if (permissionStatus != LocationPermissionStatus.granted) {
      throw StateError('Permission denied.');
    }
    return currentPosition;
  }
}

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

  late OfflinkDatabase database;
  late DriftMessageRepository messageRepository;
  late DriftConversationRepository conversationRepository;
  late DriftGroupRepository groupRepository;
  late FakePacketTransport transport;
  late FakeLocationProvider locationProvider;
  late IdentityManager identityManager;
  late IdentityKeyService keyService;
  late LocationService locationService;

  setUp(() async {
    database = OfflinkDatabase.forTesting(NativeDatabase.memory());
    messageRepository = DriftMessageRepository(database);
    conversationRepository = DriftConversationRepository(database);
    groupRepository = DriftGroupRepository(database);
    transport = FakePacketTransport();
    locationProvider = FakeLocationProvider();

    keyService = IdentityKeyService();
    final identity = OfflinkIdentity(
      nodeId: 'node-alice',
      username: 'Alice',
      publicKey: 'alice-pub-key',
      createdAt: DateTime.now().toUtc(),
    );

    identityManager = IdentityManager(
      repository: StubIdentityRepository(identity),
      keyService: keyService,
      initializationService: IdentityInitializationService(
        nodeIdGenerator: NodeIdGenerator(),
        keyService: keyService,
      ),
    );
    await identityManager.loadExistingIdentity();

    locationService = LocationService(
      locationProvider: locationProvider,
      packetTransport: transport,
      identityManager: identityManager,
      messageRepository: messageRepository,
      conversationRepository: conversationRepository,
      groupRepository: groupRepository,
      updateInterval: const Duration(seconds: 1), // Fast tick for test
    );
  });

  tearDown(() async {
    locationService.dispose();
    await transport.dispose();
    await database.close();
  });

  group('LocationService Permissions', () {
    test('reports location service and permission status', () async {
      expect(await locationService.isLocationServiceEnabled(), isTrue);
      expect(
        await locationService.checkPermission(),
        LocationPermissionStatus.granted,
      );

      locationProvider.serviceEnabled = false;
      expect(await locationService.isLocationServiceEnabled(), isFalse);

      locationProvider.permissionStatus = LocationPermissionStatus.denied;
      expect(
        await locationService.checkPermission(),
        LocationPermissionStatus.denied,
      );
      expect(
        await locationService.requestPermission(),
        LocationPermissionStatus.denied,
      );
    });
  });

  group('One-Time Location Sharing', () {
    test('sends snapshot, persists message, and emits OfflinkPacket', () async {
      final msg = await locationService.sendOneTimeLocation(
        targetId: 'node-bob',
        isGroup: false,
      );

      expect(msg.isOutgoing, isTrue);
      expect(msg.recipientNodeId, 'node-bob');
      expect(msg.senderNodeId, 'node-alice');
      expect(LocationPayload.isLocationMessage(msg.content), isTrue);

      final payload = LocationPayload.decode(msg.content);
      expect(payload.latitude, 37.7749);
      expect(payload.longitude, -122.4194);
      expect(payload.sharingType, LocationSharingType.oneTime);
      expect(payload.isLive, isFalse);

      // Verify database persistence
      final saved = await messageRepository.getMessageById(msg.id);
      expect(saved, isNotNull);
      expect(saved!.content, msg.content);

      // Verify conversation record
      final conv = await conversationRepository.getConversationById('node-bob');
      expect(conv, isNotNull);
      expect(conv!.lastMessage, '📍 Location snapshot');

      // Verify transmitted packet
      expect(transport.sentPackets.length, 1);
      final sent = transport.sentPackets.first;
      expect(sent.peerId, 'node-bob');
      expect(sent.packet.messageType, OfflinkMessageType.location);
      expect(sent.packet.recipientNodeId, 'node-bob');
      expect(sent.packet.senderNodeId, 'node-alice');

      // Correlate ACK
      final ackPacket = OfflinkPacket(
        messageId: 'ack-1',
        senderNodeId: 'node-bob',
        recipientNodeId: 'node-alice',
        messageType: OfflinkMessageType.acknowledgement,
        timestamp: DateTime.now().toUtc(),
        ttl: 3,
        payload: sent.packet.messageId,
      );
      transport.emit(ackPacket);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = await messageRepository.getMessageById(msg.id);
      expect(updated?.status, ChatMessageStatus.delivered);
    });
  });

  group('Live Location Sharing', () {
    test(
      'starts live session, sends initial tick, and updates state',
      () async {
        expect(locationService.isLiveLocationActive('node-bob'), isFalse);

        final session = await locationService.startLiveLocation(
          targetId: 'node-bob',
          isGroup: false,
          duration: const Duration(minutes: 15),
        );

        expect(session.isActive, isTrue);
        expect(session.targetId, 'node-bob');
        expect(locationService.isLiveLocationActive('node-bob'), isTrue);
        expect(locationService.getActiveLiveSession('node-bob'), isNotNull);

        // Verify initial packet was sent
        expect(transport.sentPackets.length, 1);
        final sent = transport.sentPackets.first;
        expect(sent.packet.messageType, OfflinkMessageType.location);

        final payload = LocationPayload.decode(sent.packet.payload);
        expect(payload.sharingType, LocationSharingType.liveUpdate);
        expect(payload.isLive, isTrue);
        expect(payload.liveSessionId, session.id);

        // Check conversation record
        final conv = await conversationRepository.getConversationById(
          'node-bob',
        );
        expect(conv?.lastMessage, '📍 Live location sharing');
      },
    );

    test(
      'stopping live session emits liveStop packet and updates message',
      () async {
        await locationService.startLiveLocation(
          targetId: 'node-bob',
          isGroup: false,
          duration: const Duration(minutes: 15),
        );

        transport.sentPackets.clear();

        await locationService.stopLiveLocation('node-bob');
        expect(locationService.isLiveLocationActive('node-bob'), isFalse);

        expect(transport.sentPackets.length, 1);
        final stopPacket = transport.sentPackets.first.packet;
        final stopPayload = LocationPayload.decode(stopPacket.payload);
        expect(stopPayload.sharingType, LocationSharingType.liveStop);
        expect(stopPayload.isLive, isFalse);

        final conv = await conversationRepository.getConversationById(
          'node-bob',
        );
        expect(conv?.lastMessage, '📍 Live location ended');
      },
    );

    test('skips periodic GPS capture when backgrounded', () async {
      await locationService.startLiveLocation(
        targetId: 'node-bob',
        isGroup: false,
        duration: const Duration(minutes: 15),
      );

      transport.sentPackets.clear();
      locationService.setBackgroundState(true);

      // Wait 1.5 seconds for timer tick
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(transport.sentPackets.isEmpty, isTrue);

      // Resume foreground
      locationService.setBackgroundState(false);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(transport.sentPackets.isNotEmpty, isTrue);
    });

    test('auto-stops live session when duration expires', () async {
      // Create session with 1 second duration
      await locationService.startLiveLocation(
        targetId: 'node-bob',
        isGroup: false,
        duration: const Duration(milliseconds: 500),
      );

      expect(locationService.isLiveLocationActive('node-bob'), isTrue);

      // Wait 1.5 seconds for expiration timer to trigger
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(locationService.isLiveLocationActive('node-bob'), isFalse);
    });
  });

  group('Group Location Sharing', () {
    test('fans out location payload to all group members', () async {
      final now = DateTime.now().toUtc();
      final group = Group(
        id: 'grp-1',
        name: 'Exploration Team',
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
        GroupMember(
          groupId: 'grp-1',
          memberNodeId: 'node-charlie',
          memberDisplayName: 'Charlie',
          role: GroupMemberRole.member,
          joinedAt: now,
        ),
      ];

      await groupRepository.createGroup(group, members);

      final msg = await locationService.sendOneTimeLocation(
        targetId: 'grp-1',
        isGroup: true,
      );

      expect(msg.recipientNodeId, 'grp-1');
      expect(msg.conversationId, 'group-grp-1');

      // Check fanout to Bob and Charlie (Alice excluded)
      expect(transport.sentPackets.length, 2);
      final recipients = transport.sentPackets
          .map((p) => p.packet.recipientNodeId)
          .toSet();
      expect(recipients, containsAll(['node-bob', 'node-charlie']));
      expect(recipients, isNot(contains('node-alice')));
    });
  });

  group('Incoming Location Processing', () {
    test(
      'receives and persists incoming location and emits reverse-path ACK',
      () async {
        final now = DateTime.now().toUtc();
        final payload = LocationPayload(
          locationId: 'loc-snap-bob-1',
          senderNodeId: 'node-bob',
          senderDisplayName: 'Bob',
          recipientNodeId: 'node-alice',
          latitude: 19.0760,
          longitude: 72.8777,
          accuracy: 15.0,
          timestamp: now,
          sharingType: LocationSharingType.oneTime,
          isLive: false,
        );

        final packet = OfflinkPacket(
          messageId: 'pkt-loc-1',
          senderNodeId: 'node-bob',
          recipientNodeId: 'node-alice',
          messageType: OfflinkMessageType.location,
          timestamp: now,
          ttl: 4,
          payload: payload.encode(),
        );

        transport.emit(packet);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // 1. Verify message persisted
        final saved = await messageRepository.getMessageById('loc-snap-bob-1');
        expect(saved, isNotNull);
        expect(saved!.senderNodeId, 'node-bob');
        expect(saved.isOutgoing, isFalse);

        // 2. Verify reverse-path ACK emitted
        final ackPackets = transport.sentPackets.where(
          (p) => p.packet.messageType == OfflinkMessageType.acknowledgement,
        );
        expect(ackPackets.length, 1);
        final ack = ackPackets.first;
        expect(ack.packet.recipientNodeId, 'node-bob');
        expect(ack.packet.payload, 'pkt-loc-1');
      },
    );

    test(
      'rejects packet if envelope sender does not match inner sender',
      () async {
        final now = DateTime.now().toUtc();
        final spoofedPayload = LocationPayload(
          locationId: 'loc-spoofed',
          senderNodeId: 'node-charlie', // Inner sender
          senderDisplayName: 'Charlie',
          latitude: 19.0760,
          longitude: 72.8777,
          timestamp: now,
        );

        final packet = OfflinkPacket(
          messageId: 'pkt-spoofed',
          senderNodeId: 'node-bob', // Envelope sender mismatch!
          recipientNodeId: 'node-alice',
          messageType: OfflinkMessageType.location,
          timestamp: now,
          ttl: 4,
          payload: spoofedPayload.encode(),
        );

        transport.emit(packet);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final saved = await messageRepository.getMessageById('loc-spoofed');
        expect(saved, isNull);
      },
    );

    test('rejects expired location packet', () async {
      final now = DateTime.now().toUtc();
      final expiredPayload = LocationPayload(
        locationId: 'loc-expired',
        senderNodeId: 'node-bob',
        senderDisplayName: 'Bob',
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      final packet = OfflinkPacket(
        messageId: 'pkt-expired',
        senderNodeId: 'node-bob',
        recipientNodeId: 'node-alice',
        messageType: OfflinkMessageType.location,
        timestamp: now,
        ttl: 4,
        payload: expiredPayload.encode(),
      );

      transport.emit(packet);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final saved = await messageRepository.getMessageById('loc-expired');
      expect(saved, isNull);
    });

    test('rejects group location from non-member sender', () async {
      final now = DateTime.now().toUtc();
      final group = Group(
        id: 'grp-2',
        name: 'Private Group',
        creatorNodeId: 'node-alice',
        createdAt: now,
        updatedAt: now,
      );
      final members = [
        GroupMember(
          groupId: 'grp-2',
          memberNodeId: 'node-alice',
          memberDisplayName: 'Alice',
          role: GroupMemberRole.admin,
          joinedAt: now,
        ),
      ];
      await groupRepository.createGroup(group, members);

      // David is NOT in grp-2
      final payload = LocationPayload(
        locationId: 'loc-intruder',
        senderNodeId: 'node-david',
        senderDisplayName: 'David',
        groupId: 'grp-2',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: now,
      );

      final packet = OfflinkPacket(
        messageId: 'pkt-intruder',
        senderNodeId: 'node-david',
        recipientNodeId: 'node-alice',
        messageType: OfflinkMessageType.location,
        timestamp: now,
        ttl: 4,
        payload: payload.encode(),
      );

      transport.emit(packet);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final saved = await messageRepository.getMessageById('loc-intruder');
      expect(saved, isNull);
    });
  });

  group('Zero-Plaintext Security Enforcement', () {
    test(
      'rejects transmission when secure session is required but missing',
      () async {
        final secureSessionService = SecureSessionService(
          identityKeyService: keyService,
          getLocalNodeId: () => 'node-alice',
        );

        final secureLocationService = LocationService(
          locationProvider: locationProvider,
          packetTransport: transport,
          identityManager: identityManager,
          secureSessionService: secureSessionService,
          messageRepository: messageRepository,
          conversationRepository: conversationRepository,
        );

        // node-bob does NOT have an active session with alice
        expect(
          () => secureLocationService.sendOneTimeLocation(
            targetId: 'node-bob',
            isGroup: false,
          ),
          throwsA(isA<StateError>()),
        );

        secureLocationService.dispose();
      },
    );
  });
}
