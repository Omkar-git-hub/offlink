import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/database/drift_conversation_repository.dart';
import 'package:offlink/data/database/drift_message_repository.dart';
import 'package:offlink/data/database/offlink_database.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/conversation.dart';

void main() {
  late OfflinkDatabase db;
  late DriftConversationRepository conversationRepository;
  late DriftMessageRepository messageRepository;

  setUp(() async {
    db = OfflinkDatabase.forTesting(NativeDatabase.memory());
    conversationRepository = DriftConversationRepository(db);
    messageRepository = DriftMessageRepository(db);

    // Create a parent conversation for messages
    await conversationRepository.upsertConversation(
      Conversation(
        id: 'conv-test',
        peerNodeId: 'node-peer-1',
        peerDisplayName: 'Test Peer',
        updatedAt: DateTime.utc(2026, 10, 27, 10, 0),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftMessageRepository', () {
    test('saves and retrieves messages ordered chronologically', () async {
      final t1 = DateTime.utc(2026, 10, 27, 10, 0);
      final t2 = DateTime.utc(2026, 10, 27, 10, 1);

      final msg1 = ChatMessage(
        id: 'm1',
        conversationId: 'conv-test',
        senderNodeId: 'node-local',
        recipientNodeId: 'node-peer-1',
        content: 'First message',
        timestamp: t1,
        isOutgoing: true,
        status: ChatMessageStatus.sent,
      );

      final msg2 = ChatMessage(
        id: 'm2',
        conversationId: 'conv-test',
        senderNodeId: 'node-peer-1',
        recipientNodeId: 'node-local',
        content: 'Second message',
        timestamp: t2,
        isOutgoing: false,
        status: ChatMessageStatus.delivered,
      );

      await messageRepository.saveMessage(msg2, conversationId: 'conv-test');
      await messageRepository.saveMessage(msg1, conversationId: 'conv-test');

      final messages = await messageRepository.getMessagesForConversation(
        'conv-test',
      );
      expect(messages, hasLength(2));
      expect(messages[0].id, 'm1');
      expect(messages[0].content, 'First message');
      expect(messages[0].isOutgoing, isTrue);
      expect(messages[0].status, ChatMessageStatus.sent);

      expect(messages[1].id, 'm2');
      expect(messages[1].content, 'Second message');
      expect(messages[1].isOutgoing, isFalse);
      expect(messages[1].status, ChatMessageStatus.delivered);
    });

    test('supports pagination via limit and offset', () async {
      for (var i = 0; i < 5; i++) {
        await messageRepository.saveMessage(
          ChatMessage(
            id: 'm-$i',
            conversationId: 'conv-test',
            senderNodeId: 'node-local',
            recipientNodeId: 'node-peer-1',
            content: 'Message $i',
            timestamp: DateTime.utc(2026, 10, 27, 10, i),
            isOutgoing: true,
          ),
          conversationId: 'conv-test',
        );
      }

      final page1 = await messageRepository.getMessagesForConversation(
        'conv-test',
        limit: 2,
        offset: 0,
      );
      expect(page1.map((m) => m.id).toList(), ['m-0', 'm-1']);

      final page2 = await messageRepository.getMessagesForConversation(
        'conv-test',
        limit: 2,
        offset: 2,
      );
      expect(page2.map((m) => m.id).toList(), ['m-2', 'm-3']);
    });

    test('updateMessageStatus updates status of existing message', () async {
      final msg = ChatMessage(
        id: 'msg-status',
        conversationId: 'conv-test',
        senderNodeId: 'node-local',
        recipientNodeId: 'node-peer-1',
        content: 'Status check',
        timestamp: DateTime.utc(2026, 10, 27, 10, 0),
        isOutgoing: true,
        status: ChatMessageStatus.sending,
      );

      await messageRepository.saveMessage(msg, conversationId: 'conv-test');
      await messageRepository.updateMessageStatus(
        'msg-status',
        ChatMessageStatus.failed,
      );

      final messages = await messageRepository.getMessagesForConversation(
        'conv-test',
      );
      expect(messages.first.status, ChatMessageStatus.failed);
    });

    test(
      'deleteMessagesForConversation removes all messages in conversation',
      () async {
        await messageRepository.saveMessage(
          ChatMessage(
            id: 'm-del',
            conversationId: 'conv-test',
            senderNodeId: 'node-local',
            recipientNodeId: 'node-peer-1',
            content: 'Delete me',
            timestamp: DateTime.utc(2026, 10, 27, 10, 0),
            isOutgoing: true,
          ),
          conversationId: 'conv-test',
        );

        await messageRepository.deleteMessagesForConversation('conv-test');
        final messages = await messageRepository.getMessagesForConversation(
          'conv-test',
        );
        expect(messages, isEmpty);
      },
    );

    test('watchMessagesForConversation emits updates on save', () async {
      final stream = messageRepository.watchMessagesForConversation(
        'conv-test',
      );
      final updatedEmission = stream.firstWhere((list) => list.isNotEmpty);

      await messageRepository.saveMessage(
        ChatMessage(
          id: 'm-stream',
          conversationId: 'conv-test',
          senderNodeId: 'node-local',
          recipientNodeId: 'node-peer-1',
          content: 'Streamed message',
          timestamp: DateTime.utc(2026, 10, 27, 10, 0),
          isOutgoing: true,
        ),
        conversationId: 'conv-test',
      );

      final messages = await updatedEmission;
      expect(messages, hasLength(1));
      expect(messages.first.id, 'm-stream');
    });
  });
}
