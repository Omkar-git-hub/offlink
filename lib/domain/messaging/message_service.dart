import 'chat_message.dart';

abstract interface class MessageService {
  Stream<ChatMessage> get incomingMessages;

  Future<ChatMessage> sendMessage({
    required String peerId,
    required String recipientNodeId,
    required String content,
  });

  void dispose();
}
