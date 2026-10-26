// ignore_for_file: prefer_initializing_formals

import 'dart:async';

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
  }) : _packetTransport = packetTransport,
       _identityManager = identityManager,
       _messageRepository = messageRepository,
       _conversationRepository = conversationRepository {
    _subscription = _packetTransport.incomingPackets.listen(
      _handleIncomingPacket,
    );
  }

  final PacketTransport _packetTransport;
  final IdentityManager _identityManager;
  final MessageRepository? _messageRepository;
  final ConversationRepository? _conversationRepository;

  final StreamController<ChatMessage> _incomingMessagesController =
      StreamController<ChatMessage>.broadcast();

  StreamSubscription<OfflinkPacket>? _subscription;

  @override
  Stream<ChatMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  Future<void> _handleIncomingPacket(OfflinkPacket packet) async {
    if (packet.messageType != OfflinkMessageType.text) {
      return;
    }

    final message = ChatMessage(
      id: packet.messageId,
      conversationId: packet.senderNodeId,
      senderNodeId: packet.senderNodeId,
      recipientNodeId: packet.recipientNodeId,
      content: packet.payload,
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
        lastMessage: packet.payload,
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

    final packet = OfflinkPacket(
      messageId: messageId,
      senderNodeId: localNodeId,
      recipientNodeId: recipientNodeId,
      messageType: OfflinkMessageType.text,
      timestamp: now,
      ttl: 3,
      payload: trimmedContent,
    );

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

    await _packetTransport.sendPacket(peerId: peerId, packet: packet);

    return message;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _incomingMessagesController.close();
  }
}
