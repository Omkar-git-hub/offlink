import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/encrypted_payload.dart';
import 'package:offlink/crypto/session/handshake_payload.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

import '../identity/fakes/fake_secure_key_storage.dart';

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
  group('DirectMessageService with SecureSessionService', () {
    late FakePacketTransport transport;
    late IdentityManager aliceIdentityManager;
    late IdentityKeyService aliceKeyService;
    late SecureSessionService aliceSessionService;
    late OfflinkDatabase database;
    late DriftMessageRepository messageRepository;
    late DriftConversationRepository conversationRepository;
    late DirectMessageService service;

    late IdentityKeyService bobKeyService;
    late SecureSessionService bobSessionService;

    const aliceNodeId = 'alice-node-1111';
    const bobNodeId = 'bob-node-2222';

    setUp(() async {
      transport = FakePacketTransport();

      aliceKeyService = IdentityKeyService(
        secureStorage: FakeSecureKeyStorage(),
      );
      final aliceKeyPair = await aliceKeyService.generateKeyPair();
      await aliceKeyService.storePrivateKey(aliceKeyPair.privateKey);

      final alicePubHex = (await aliceKeyService.exportPublicKey(
        aliceKeyPair.publicKey,
      )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final aliceIdentity = OfflinkIdentity(
        nodeId: aliceNodeId,
        username: 'Alice',
        publicKey: alicePubHex,
        createdAt: DateTime.utc(2026, 11, 17),
      );

      aliceIdentityManager = IdentityManager(
        repository: StubIdentityRepository(aliceIdentity),
        initializationService: IdentityInitializationService(
          nodeIdGenerator: NodeIdGenerator(),
          keyService: aliceKeyService,
        ),
        keyService: aliceKeyService,
      );
      await aliceIdentityManager.loadExistingIdentity();

      aliceSessionService = SecureSessionService(
        identityKeyService: aliceKeyService,
        getLocalNodeId: () => aliceNodeId,
      );

      bobKeyService = IdentityKeyService(secureStorage: FakeSecureKeyStorage());
      final bobKeyPair = await bobKeyService.generateKeyPair();
      await bobKeyService.storePrivateKey(bobKeyPair.privateKey);

      bobSessionService = SecureSessionService(
        identityKeyService: bobKeyService,
        getLocalNodeId: () => bobNodeId,
      );

      database = OfflinkDatabase.forTesting(NativeDatabase.memory());
      messageRepository = DriftMessageRepository(database);
      conversationRepository = DriftConversationRepository(database);

      service = DirectMessageService(
        packetTransport: transport,
        identityManager: aliceIdentityManager,
        messageRepository: messageRepository,
        conversationRepository: conversationRepository,
        secureSessionService: aliceSessionService,
      );
    });

    tearDown(() async {
      service.dispose();
      await transport.dispose();
      await database.close();
    });

    test(
      'performs handshake exchange and marks secure session active',
      () async {
        expect(service.hasSecureSession(bobNodeId), isFalse);

        // Alice initiates secure session
        await service.initiateSecureSession(
          peerId: 'peer-bob',
          recipientNodeId: bobNodeId,
        );

        expect(transport.sentPackets.length, 1);
        final initPacket = transport.sentPackets.first.packet;
        expect(initPacket.messageType, OfflinkMessageType.handshakeInit);

        // Bob receives handshake init and generates handshake response
        final initPayload = HandshakeInitPayload.decode(initPacket.payload);
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );

        final respPacket = OfflinkPacket(
          messageId: 'resp-1',
          senderNodeId: bobNodeId,
          recipientNodeId: aliceNodeId,
          messageType: OfflinkMessageType.handshakeResponse,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: responsePayload.encode(),
        );

        // Emit response to Alice's service
        transport.emit(respPacket);

        // Wait a microtask for stream processing
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(service.hasSecureSession(bobNodeId), isTrue);
      },
    );

    test(
      'sends encrypted packet on wire when session is active and saves plaintext locally',
      () async {
        // 1. Establish session first
        await service.initiateSecureSession(
          peerId: 'peer-bob',
          recipientNodeId: bobNodeId,
        );
        final initPacket = transport.sentPackets.first.packet;
        final initPayload = HandshakeInitPayload.decode(initPacket.payload);
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );
        transport.emit(
          OfflinkPacket(
            messageId: 'resp-1',
            senderNodeId: bobNodeId,
            recipientNodeId: aliceNodeId,
            messageType: OfflinkMessageType.handshakeResponse,
            timestamp: DateTime.now().toUtc(),
            ttl: 3,
            payload: responsePayload.encode(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(service.hasSecureSession(bobNodeId), isTrue);

        // 2. Alice sends a message to Bob
        final message = await service.sendMessage(
          peerId: 'peer-bob',
          recipientNodeId: bobNodeId,
          content: 'Confidential offline data',
        );

        expect(message.content, 'Confidential offline data');
        expect(message.isOutgoing, isTrue);

        // The packet sent over BLE wire must be encrypted
        final sentEncrypted = transport.sentPackets.last.packet;
        expect(sentEncrypted.messageType, OfflinkMessageType.encrypted);
        expect(
          sentEncrypted.payload,
          isNot(contains('Confidential offline data')),
        );

        // Decoded packet payload is a valid EncryptedPayload
        final encryptedPayload = EncryptedPayload.decode(sentEncrypted.payload);
        expect(encryptedPayload.sequenceNumber, 1);

        // Bob decrypts it
        final bobDecrypted = await bobSessionService.decrypt(
          peerNodeId: aliceNodeId,
          encryptedPayload: encryptedPayload,
          messageId: sentEncrypted.messageId,
          senderNodeId: aliceNodeId,
          recipientNodeId: bobNodeId,
        );
        expect(bobDecrypted, equals('Confidential offline data'));

        // Locally saved in database as plaintext for user display
        final savedMessages = await messageRepository
            .getMessagesForConversation(bobNodeId);
        expect(savedMessages.length, 1);
        expect(savedMessages.first.content, 'Confidential offline data');
      },
    );

    test('decrypts incoming encrypted packets and saves plaintext', () async {
      // 1. Establish session
      await service.initiateSecureSession(
        peerId: 'peer-bob',
        recipientNodeId: bobNodeId,
      );
      final initPacket = transport.sentPackets.first.packet;
      final initPayload = HandshakeInitPayload.decode(initPacket.payload);
      final responsePayload = await bobSessionService.handleHandshakeInit(
        initPayload,
      );
      transport.emit(
        OfflinkPacket(
          messageId: 'resp-1',
          senderNodeId: bobNodeId,
          recipientNodeId: aliceNodeId,
          messageType: OfflinkMessageType.handshakeResponse,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: responsePayload.encode(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 2. Bob sends encrypted message to Alice
      const bobPlaintext = 'Greetings from Bob securely';
      const bobMsgId = 'msg-bob-99';
      final encryptedFromBob = await bobSessionService.encrypt(
        peerNodeId: aliceNodeId,
        plaintext: bobPlaintext,
        messageId: bobMsgId,
        senderNodeId: bobNodeId,
        recipientNodeId: aliceNodeId,
      );

      final incomingFuture = service.incomingMessages.first;

      transport.emit(
        OfflinkPacket(
          messageId: bobMsgId,
          senderNodeId: bobNodeId,
          recipientNodeId: aliceNodeId,
          messageType: OfflinkMessageType.encrypted,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: encryptedFromBob.encode(),
        ),
      );

      final receivedMessage = await incomingFuture;
      expect(receivedMessage.id, bobMsgId);
      expect(receivedMessage.content, bobPlaintext);
      expect(receivedMessage.senderNodeId, bobNodeId);
      expect(receivedMessage.isOutgoing, isFalse);

      // Persisted in repository
      final savedMessages = await messageRepository.getMessagesForConversation(
        bobNodeId,
      );
      expect(savedMessages.length, 1);
      expect(savedMessages.first.content, bobPlaintext);
    });

    test(
      'discards tampered encrypted packets without saving or emitting',
      () async {
        // Establish session
        await service.initiateSecureSession(
          peerId: 'peer-bob',
          recipientNodeId: bobNodeId,
        );
        final initPacket = transport.sentPackets.first.packet;
        final initPayload = HandshakeInitPayload.decode(initPacket.payload);
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );
        transport.emit(
          OfflinkPacket(
            messageId: 'resp-1',
            senderNodeId: bobNodeId,
            recipientNodeId: aliceNodeId,
            messageType: OfflinkMessageType.handshakeResponse,
            timestamp: DateTime.now().toUtc(),
            ttl: 3,
            payload: responsePayload.encode(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final encryptedFromBob = await bobSessionService.encrypt(
          peerNodeId: aliceNodeId,
          plaintext: 'Valid text',
          messageId: 'msg-tampered-1',
          senderNodeId: bobNodeId,
          recipientNodeId: aliceNodeId,
        );

        // Tamper ciphertext
        final rawCipher = base64Decode(encryptedFromBob.ciphertext);
        rawCipher[0] ^= 0xFF;
        final tamperedPayload = EncryptedPayload(
          ciphertext: base64Encode(rawCipher),
          nonce: encryptedFromBob.nonce,
          mac: encryptedFromBob.mac,
          sequenceNumber: encryptedFromBob.sequenceNumber,
          sessionFingerprint: encryptedFromBob.sessionFingerprint,
        );

        var messageReceived = false;
        final sub = service.incomingMessages.listen((_) {
          messageReceived = true;
        });

        transport.emit(
          OfflinkPacket(
            messageId: 'msg-tampered-1',
            senderNodeId: bobNodeId,
            recipientNodeId: aliceNodeId,
            messageType: OfflinkMessageType.encrypted,
            timestamp: DateTime.now().toUtc(),
            ttl: 3,
            payload: tamperedPayload.encode(),
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(messageReceived, isFalse);

        final saved = await messageRepository.getMessagesForConversation(
          bobNodeId,
        );
        expect(saved, isEmpty);

        await sub.cancel();
      },
    );

    test(
      'exchanges senderUsername in handshake and updates peer identity and conversation repository',
      () async {
        // Collect peer identity updates
        final receivedIdentities = <({String peerId, String username})>[];
        final sub = service.peerIdentityUpdates.listen(receivedIdentities.add);

        // 1. Alice initiates handshake
        await service.initiateSecureSession(
          peerId: 'peer-bob',
          recipientNodeId: bobNodeId,
        );

        expect(transport.sentPackets, isNotEmpty);
        final initPacket = transport.sentPackets.first.packet;
        final initPayload = HandshakeInitPayload.decode(initPacket.payload);
        // Alice includes her identity username in HandshakeInitPayload
        expect(initPayload.senderUsername, equals('Alice'));

        // 2. Bob handles init and responds with his username 'Bob'
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
          senderUsername: 'Bob',
        );
        expect(responsePayload.senderUsername, equals('Bob'));

        // 3. Emit handshakeResponse packet from Bob to Alice
        transport.emit(
          OfflinkPacket(
            messageId: 'resp-username-1',
            senderNodeId: bobNodeId,
            recipientNodeId: aliceNodeId,
            messageType: OfflinkMessageType.handshakeResponse,
            timestamp: DateTime.now().toUtc(),
            ttl: 3,
            payload: responsePayload.encode(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // 4. Verify Alice received Bob's username via stream
        expect(receivedIdentities, isNotEmpty);
        expect(receivedIdentities.first.peerId, equals(bobNodeId));
        expect(receivedIdentities.first.username, equals('Bob'));

        // 5. Verify conversation repository updated peerDisplayName to 'Bob'
        final conversation = await conversationRepository.getConversationByPeer(
          bobNodeId,
        );
        expect(conversation, isNotNull);
        expect(conversation!.peerDisplayName, equals('Bob'));

        await sub.cancel();
      },
    );
  });
}
