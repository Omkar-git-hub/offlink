// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../identity/identity_manager.dart';
import '../protocol/offlink_message_type.dart';
import '../protocol/offlink_packet.dart';
import '../protocol/packet_transport.dart';
import 'chat_message.dart';
import 'message_service.dart';

class DirectMessageService implements MessageService {
  DirectMessageService({
    required PacketTransport packetTransport,
    required IdentityManager identityManager,
  }) : _packetTransport = packetTransport,
       _identityManager = identityManager {
    _subscription = _packetTransport.incomingPackets.listen(
      _handleIncomingPacket,
    );
  }

  final PacketTransport _packetTransport;
  final IdentityManager _identityManager;

  final StreamController<ChatMessage> _incomingMessagesController =
      StreamController<ChatMessage>.broadcast();

  StreamSubscription<OfflinkPacket>? _subscription;

  @override
  Stream<ChatMessage> get incomingMessages =>
      _incomingMessagesController.stream;

  void _handleIncomingPacket(OfflinkPacket packet) {
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

    await _packetTransport.sendPacket(peerId: peerId, packet: packet);

    return ChatMessage(
      id: messageId,
      conversationId: recipientNodeId,
      senderNodeId: localNodeId,
      recipientNodeId: recipientNodeId,
      content: trimmedContent,
      timestamp: now,
      isOutgoing: true,
      status: ChatMessageStatus.sent,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _incomingMessagesController.close();
  }
}
