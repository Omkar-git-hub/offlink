import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
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
  group('DirectMessageService', () {
    late FakePacketTransport transport;
    late IdentityManager identityManager;
    late DirectMessageService service;

    final testIdentity = OfflinkIdentity(
      nodeId: 'node-alice-1234',
      username: 'Alice',
      publicKey: '00112233445566778899aabbccddeeff',
      createdAt: DateTime.utc(2026, 9, 22),
    );

    setUp(() async {
      transport = FakePacketTransport();

      identityManager = IdentityManager(
        repository: StubIdentityRepository(testIdentity),
        initializationService: IdentityInitializationService(
          nodeIdGenerator: NodeIdGenerator(),
          keyService: IdentityKeyService(),
        ),
        keyService: IdentityKeyService(),
      );

      await identityManager.loadExistingIdentity();

      service = DirectMessageService(
        packetTransport: transport,
        identityManager: identityManager,
      );
    });

    tearDown(() async {
      service.dispose();
      await transport.dispose();
    });

    test('sends outgoing message and transmits valid text packet', () async {
      final message = await service.sendMessage(
        peerId: 'peer-bob-device-id',
        recipientNodeId: 'node-bob-5678',
        content: 'Hello Bob!',
      );

      expect(message.content, 'Hello Bob!');
      expect(message.recipientNodeId, 'node-bob-5678');
      expect(message.senderNodeId, 'node-alice-1234');
      expect(message.isOutgoing, isTrue);
      expect(message.status, ChatMessageStatus.sent);

      expect(transport.sentPackets, hasLength(1));
      final sent = transport.sentPackets.first;
      expect(sent.peerId, 'peer-bob-device-id');
      expect(sent.packet.messageType, OfflinkMessageType.text);
      expect(sent.packet.payload, 'Hello Bob!');
      expect(sent.packet.senderNodeId, 'node-alice-1234');
      expect(sent.packet.recipientNodeId, 'node-bob-5678');
    });

    test('rejects empty or whitespace-only messages', () async {
      expect(
        () => service.sendMessage(
          peerId: 'peer-bob',
          recipientNodeId: 'node-bob',
          content: '   ',
        ),
        throwsArgumentError,
      );
      expect(transport.sentPackets, isEmpty);
    });

    test('converts incoming text packet to ChatMessage', () async {
      final now = DateTime.utc(2026, 9, 22, 11, 30);
      final packet = OfflinkPacket(
        messageId: 'incoming-msg-99',
        senderNodeId: 'node-bob-5678',
        recipientNodeId: 'node-alice-1234',
        messageType: OfflinkMessageType.text,
        timestamp: now,
        ttl: 3,
        payload: 'Hi Alice, nice to connect!',
      );

      final messageFuture = service.incomingMessages.first;
      transport.emit(packet);

      final receivedMessage = await messageFuture;
      expect(receivedMessage.id, 'incoming-msg-99');
      expect(receivedMessage.senderNodeId, 'node-bob-5678');
      expect(receivedMessage.recipientNodeId, 'node-alice-1234');
      expect(receivedMessage.content, 'Hi Alice, nice to connect!');
      expect(receivedMessage.isOutgoing, isFalse);
      expect(receivedMessage.status, ChatMessageStatus.delivered);
    });

    test('ignores non-text incoming packets', () async {
      final packet = OfflinkPacket(
        messageId: 'ack-msg-1',
        senderNodeId: 'node-bob-5678',
        recipientNodeId: 'node-alice-1234',
        messageType: OfflinkMessageType.acknowledgement,
        timestamp: DateTime.utc(2026, 9, 22, 11, 30),
        ttl: 3,
        payload: 'ack-payload',
      );

      final messages = <ChatMessage>[];
      final subscription = service.incomingMessages.listen(messages.add);

      transport.emit(packet);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(messages, isEmpty);
      await subscription.cancel();
    });
  });
}
