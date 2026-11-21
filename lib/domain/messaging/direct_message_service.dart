// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../crypto/session/encrypted_payload.dart';
import '../../crypto/session/handshake_payload.dart';
import '../../crypto/session/secure_session_service.dart';
import '../identity/identity_manager.dart';
import '../protocol/offlink_message_type.dart';
import '../protocol/offlink_packet.dart';
import '../protocol/packet_transport.dart';
import 'chat_message.dart';
import 'conversation.dart';
import 'conversation_repository.dart';
import 'message_repository.dart';
import 'message_service.dart';

class DirectMessageService implements MessageService {
  DirectMessageService({
    required PacketTransport packetTransport,
    required IdentityManager identityManager,
    MessageRepository? messageRepository,
    ConversationRepository? conversationRepository,
    SecureSessionService? secureSessionService,
  }) : _packetTransport = packetTransport,
       _identityManager = identityManager,
       _messageRepository = messageRepository,
       _conversationRepository = conversationRepository,
       _secureSessionService = secureSessionService {
    _subscription = _packetTransport.incomingPackets.listen(
      _handleIncomingPacket,
    );
  }

  final PacketTransport _packetTransport;
  final IdentityManager _identityManager;
  final MessageRepository? _messageRepository;
  final ConversationRepository? _conversationRepository;
  final SecureSessionService? _secureSessionService;

  final StreamController<ChatMessage> _incomingMessagesController =
      StreamController<ChatMessage>.broadcast();

  StreamSubscription<OfflinkPacket>? _subscription;

  @override
  Stream<ChatMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  bool hasSecureSession(String peerNodeId) {
    return _secureSessionService?.hasSession(peerNodeId) ?? false;
  }

  Future<void> initiateSecureSession({
    required String peerId,
    required String recipientNodeId,
  }) async {
    if (_secureSessionService == null) {
      return;
    }

    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final handshakeInit = await _secureSessionService.createHandshakeInit(
      recipientNodeId,
    );

    final packet = OfflinkPacket(
      messageId: 'handshake-init-${DateTime.now().microsecondsSinceEpoch}',
      senderNodeId: localNodeId,
      recipientNodeId: recipientNodeId,
      messageType: OfflinkMessageType.handshakeInit,
      timestamp: DateTime.now().toUtc(),
      ttl: 3,
      payload: handshakeInit.encode(),
    );

    await _packetTransport.sendPacket(peerId: peerId, packet: packet);
  }

  Future<void> _handleIncomingPacket(OfflinkPacket packet) async {
    // Ignore group and location packets; handled by their respective services
    if (packet.messageType == OfflinkMessageType.groupMessage ||
        packet.messageType == OfflinkMessageType.groupMembership ||
        packet.messageType == OfflinkMessageType.location) {
      return;
    }

    if (packet.messageType == OfflinkMessageType.handshakeInit) {
      if (_secureSessionService == null) {
        return;
      }
      try {
        final initPayload = HandshakeInitPayload.decode(packet.payload);
        final responsePayload = await _secureSessionService.handleHandshakeInit(
          initPayload,
        );

        final localNodeId =
            _identityManager.currentIdentity?.nodeId ?? 'local-node';
        final responsePacket = OfflinkPacket(
          messageId: 'handshake-resp-${DateTime.now().microsecondsSinceEpoch}',
          senderNodeId: localNodeId,
          recipientNodeId: packet.senderNodeId,
          messageType: OfflinkMessageType.handshakeResponse,
          timestamp: DateTime.now().toUtc(),
          ttl: 3,
          payload: responsePayload.encode(),
        );

        await _packetTransport.sendPacket(
          peerId: packet.senderNodeId,
          packet: responsePacket,
        );
      } catch (_) {
        return;
      }
      return;
    }

    if (packet.messageType == OfflinkMessageType.handshakeResponse) {
      if (_secureSessionService == null) {
        return;
      }
      try {
        final responsePayload = HandshakeResponsePayload.decode(packet.payload);
        await _secureSessionService.handleHandshakeResponse(responsePayload);
      } catch (_) {
        return;
      }
      return;
    }

    if (packet.messageType == OfflinkMessageType.acknowledgement) {
      final ackMessageId = packet.payload;
      if (_messageRepository != null) {
        await _messageRepository.updateMessageStatus(
          ackMessageId,
          ChatMessageStatus.delivered,
        );
      }
      return;
    }

    String messageContent;

    if (packet.messageType == OfflinkMessageType.encrypted) {
      if (_secureSessionService == null) {
        return;
      }
      try {
        final encryptedPayload = EncryptedPayload.decode(packet.payload);
        messageContent = await _secureSessionService.decrypt(
          peerNodeId: packet.senderNodeId,
          encryptedPayload: encryptedPayload,
          messageId: packet.messageId,
          senderNodeId: packet.senderNodeId,
          recipientNodeId: packet.recipientNodeId,
        );
      } catch (_) {
        // Discard packet on authentication failure or replay attack without leaking plaintext
        return;
      }
    } else if (packet.messageType == OfflinkMessageType.text) {
      messageContent = packet.payload;
    } else {
      return;
    }

    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final ackPacket = OfflinkPacket(
      messageId: 'ack-${DateTime.now().microsecondsSinceEpoch}',
      senderNodeId: localNodeId,
      recipientNodeId: packet.senderNodeId,
      messageType: OfflinkMessageType.acknowledgement,
      timestamp: DateTime.now().toUtc(),
      ttl: 4,
      payload: packet.messageId,
    );

    // Idempotent deduplication check:
    // If this message was already received and persisted, still send the delivery ACK back
    // so the sender knows it was received, but do NOT increment unreadCount or emit duplicate UI events.
    if (_messageRepository != null) {
      final existing = await _messageRepository.getMessageById(
        packet.messageId,
      );
      if (existing != null) {
        try {
          await _packetTransport.sendPacket(
            peerId: packet.senderNodeId,
            packet: ackPacket,
          );
        } catch (_) {}
        return;
      }
    }

    final message = ChatMessage(
      id: packet.messageId,
      conversationId: packet.senderNodeId,
      senderNodeId: packet.senderNodeId,
      recipientNodeId: packet.recipientNodeId,
      content: messageContent,
      timestamp: packet.timestamp,
      isOutgoing: false,
      status: ChatMessageStatus.delivered,
    );

    if (_conversationRepository != null) {
      final existing = await _conversationRepository.getConversationByPeer(
        packet.senderNodeId,
      );
      final conversation = Conversation(
        id: existing?.id ?? packet.senderNodeId,
        peerNodeId: packet.senderNodeId,
        peerDisplayName:
            existing?.peerDisplayName ??
            'Peer ${packet.senderNodeId.length > 8 ? packet.senderNodeId.substring(0, 8) : packet.senderNodeId}',
        lastMessage: messageContent,
        unreadCount: (existing?.unreadCount ?? 0) + 1,
        updatedAt: packet.timestamp,
      );
      await _conversationRepository.upsertConversation(conversation);
    }

    if (_messageRepository != null) {
      await _messageRepository.saveMessage(
        message,
        conversationId: packet.senderNodeId,
      );
    }

    _incomingMessagesController.add(message);

    try {
      await _packetTransport.sendPacket(
        peerId: packet.senderNodeId,
        packet: ackPacket,
      );
    } catch (_) {
      // Best-effort mesh delivery confirmation
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String peerId,
    required String recipientNodeId,
    required String content,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw ArgumentError('Message content cannot be empty.');
    }

    final localNodeId =
        _identityManager.currentIdentity?.nodeId ?? 'local-node';
    final messageId = 'msg-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc();

    OfflinkPacket packet;
    if (_secureSessionService != null &&
        _secureSessionService.hasSession(recipientNodeId)) {
      final encryptedPayload = await _secureSessionService.encrypt(
        peerNodeId: recipientNodeId,
        plaintext: trimmedContent,
        messageId: messageId,
        senderNodeId: localNodeId,
        recipientNodeId: recipientNodeId,
      );

      packet = OfflinkPacket(
        messageId: messageId,
        senderNodeId: localNodeId,
        recipientNodeId: recipientNodeId,
        messageType: OfflinkMessageType.encrypted,
        timestamp: now,
        ttl: 3,
        payload: encryptedPayload.encode(),
      );
    } else {
      packet = OfflinkPacket(
        messageId: messageId,
        senderNodeId: localNodeId,
        recipientNodeId: recipientNodeId,
        messageType: OfflinkMessageType.text,
        timestamp: now,
        ttl: 3,
        payload: trimmedContent,
      );
    }

    final message = ChatMessage(
      id: messageId,
      conversationId: recipientNodeId,
      senderNodeId: localNodeId,
      recipientNodeId: recipientNodeId,
      content: trimmedContent,
      timestamp: now,
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );

    if (_conversationRepository != null) {
      final existing = await _conversationRepository.getConversationByPeer(
        recipientNodeId,
      );
      final conversation = Conversation(
        id: existing?.id ?? recipientNodeId,
        peerNodeId: recipientNodeId,
        peerDisplayName:
            existing?.peerDisplayName ??
            'Peer ${recipientNodeId.length > 8 ? recipientNodeId.substring(0, 8) : recipientNodeId}',
        lastMessage: trimmedContent,
        unreadCount: existing?.unreadCount ?? 0,
        updatedAt: now,
      );
      await _conversationRepository.upsertConversation(conversation);
    }

    if (_messageRepository != null) {
      await _messageRepository.saveMessage(
        message,
        conversationId: recipientNodeId,
      );
    }

    try {
      await _packetTransport.sendPacket(peerId: peerId, packet: packet);
    } catch (_) {
      // Saved in offline message queue; recovery service will retry when connected
    }

    return message;
  }

  Future<void> retryMessage({
    required ChatMessage message,
    String? peerId,
  }) async {
    final targetPeer = peerId ?? message.recipientNodeId;
    final now = DateTime.now().toUtc();

    OfflinkPacket packet;
    if (_secureSessionService != null &&
        _secureSessionService.hasSession(message.recipientNodeId)) {
      final encryptedPayload = await _secureSessionService.encrypt(
        peerNodeId: message.recipientNodeId,
        plaintext: message.content,
        messageId: message.id,
        senderNodeId: message.senderNodeId,
        recipientNodeId: message.recipientNodeId,
      );

      packet = OfflinkPacket(
        messageId: message.id,
        senderNodeId: message.senderNodeId,
        recipientNodeId: message.recipientNodeId,
        messageType: OfflinkMessageType.encrypted,
        timestamp: now,
        ttl: 4,
        payload: encryptedPayload.encode(),
      );
    } else {
      packet = OfflinkPacket(
        messageId: message.id,
        senderNodeId: message.senderNodeId,
        recipientNodeId: message.recipientNodeId,
        messageType: OfflinkMessageType.text,
        timestamp: now,
        ttl: 4,
        payload: message.content,
      );
    }

    await _packetTransport.sendPacket(peerId: targetPeer, packet: packet);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _incomingMessagesController.close();
  }
}
