import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/messaging/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('creates ChatMessage with specified properties', () {
      final now = DateTime.utc(2026, 9, 22, 10, 0);
      final message = ChatMessage(
        id: 'msg-1',
        conversationId: 'peer-1',
        senderNodeId: 'node-alice',
        recipientNodeId: 'peer-1',
        content: 'Hello via BLE',
        timestamp: now,
        isOutgoing: true,
        status: ChatMessageStatus.sent,
      );

      expect(message.id, 'msg-1');
      expect(message.conversationId, 'peer-1');
      expect(message.senderNodeId, 'node-alice');
      expect(message.recipientNodeId, 'peer-1');
      expect(message.content, 'Hello via BLE');
      expect(message.timestamp, now);
      expect(message.isOutgoing, isTrue);
      expect(message.status, ChatMessageStatus.sent);
    });

    test('copyWith updates specified fields only', () {
      final now = DateTime.utc(2026, 9, 22, 10, 0);
      final message = ChatMessage(
        id: 'msg-1',
        conversationId: 'peer-1',
        senderNodeId: 'node-alice',
        recipientNodeId: 'peer-1',
        content: 'Initial',
        timestamp: now,
        isOutgoing: true,
        status: ChatMessageStatus.sending,
      );

      final updated = message.copyWith(
        content: 'Updated',
        status: ChatMessageStatus.delivered,
      );

      expect(updated.id, 'msg-1');
      expect(updated.content, 'Updated');
      expect(updated.status, ChatMessageStatus.delivered);
      expect(updated.isOutgoing, isTrue);
    });
  });
}
