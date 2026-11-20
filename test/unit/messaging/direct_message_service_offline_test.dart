import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

class _FakePacketTransport implements PacketTransport {
  final List<String> peers = [];
  final List<OfflinkPacket> sentPackets = [];
  final StreamController<OfflinkPacket> _incomingController =
      StreamController<OfflinkPacket>.broadcast();
  bool shouldFailSend = false;

  @override
  List<String> get connectedPeerIds => List.unmodifiable(peers);

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingController.stream;

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    if (shouldFailSend) {
      throw StateError('Link unavailable');
    }
    sentPackets.add(packet);
  }

  void deliver(OfflinkPacket packet) {
    _incomingController.add(packet);
  }

  void dispose() {
    _incomingController.close();
  }
}

class _FakeIdentityManager implements IdentityManager {
  _FakeIdentityManager(this.nodeId);
  final String nodeId;

  @override
  OfflinkIdentity? get currentIdentity => OfflinkIdentity(
    nodeId: nodeId,
    username: 'Node-$nodeId',
    publicKey: 'pubkey-$nodeId',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DirectMessageService Offline & Deduplication', () {
    late OfflinkDatabase db;
    late DriftMessageRepository messageRepo;
    late DriftConversationRepository conversationRepo;
    late _FakePacketTransport transport;
    late DirectMessageService service;

    setUp(() {
      db = OfflinkDatabase.forTesting(NativeDatabase.memory());
      messageRepo = DriftMessageRepository(db);
      conversationRepo = DriftConversationRepository(db);
      transport = _FakePacketTransport();

      service = DirectMessageService(
        packetTransport: transport,
        identityManager: _FakeIdentityManager('node-local'),
        messageRepository: messageRepo,
        conversationRepository: conversationRepo,
      );
    });

    tearDown(() async {
      service.dispose();
      transport.dispose();
      await db.close();
    });

    test(
      'persists outgoing message with sent status when transport fails (offline send)',
      () async {
        transport.shouldFailSend = true;

        final message = await service.sendMessage(
          peerId: 'peer-offline',
          recipientNodeId: 'peer-offline',
          content: 'Offline note',
        );

        expect(message.id, startsWith('msg-'));
        expect(message.status, equals(ChatMessageStatus.sent));

        final persisted = await messageRepo.getMessageById(message.id);
        expect(persisted, isNotNull);
        expect(persisted!.content, equals('Offline note'));
        expect(persisted.status, equals(ChatMessageStatus.sent));

        final pending = await messageRepo.getPendingMessages();
        expect(pending, hasLength(1));
        expect(pending.first.id, equals(message.id));
      },
    );

    test(
      'recipient deduplicates duplicate message delivery while reliably resending ACK',
      () async {
        final incomingEvents = <ChatMessage>[];
        final subscription = service.incomingMessages.listen(
          incomingEvents.add,
        );

        final now = DateTime.now().toUtc();
        final packet = OfflinkPacket(
          messageId: 'msg-dup-123',
          senderNodeId: 'peer-alice',
          recipientNodeId: 'node-local',
          messageType: OfflinkMessageType.text,
          payload: 'First time payload',
          timestamp: now,
          ttl: 3,
        );

        // 1. Deliver packet first time
        transport.deliver(packet);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(incomingEvents, hasLength(1));
        expect(incomingEvents.first.id, equals('msg-dup-123'));
        expect(transport.sentPackets, hasLength(1));
        expect(
          transport.sentPackets.first.messageType,
          equals(OfflinkMessageType.acknowledgement),
        );
        expect(transport.sentPackets.first.payload, equals('msg-dup-123'));

        final conversationBefore = await conversationRepo.getConversationByPeer(
          'peer-alice',
        );
        expect(conversationBefore!.unreadCount, equals(1));

        // 2. Deliver identical packet second time (simulating retransmission because ACK was lost in transit)
        transport.deliver(packet);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Incoming stream should NOT have emitted a second time!
        expect(incomingEvents, hasLength(1));

        // Unread count should NOT have doubled
        final conversationAfter = await conversationRepo.getConversationByPeer(
          'peer-alice',
        );
        expect(conversationAfter!.unreadCount, equals(1));

        // But a second ACK MUST have been sent to satisfy the sender's retry!
        expect(transport.sentPackets, hasLength(2));
        expect(
          transport.sentPackets.last.messageType,
          equals(OfflinkMessageType.acknowledgement),
        );
        expect(transport.sentPackets.last.payload, equals('msg-dup-123'));

        await subscription.cancel();
      },
    );
  });
}
