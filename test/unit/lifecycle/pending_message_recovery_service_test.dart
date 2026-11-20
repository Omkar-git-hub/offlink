import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/lifecycle/pending_message_recovery_service.dart';
import 'package:offlink/domain/messaging/chat_message.dart';
import 'package:offlink/domain/messaging/direct_message_service.dart';
import 'package:offlink/domain/messaging/message_repository.dart';

class _MockMessageRepo implements MessageRepository {
  final List<ChatMessage> pending = [];
  final Map<String, ChatMessageStatus> updatedStatuses = {};

  @override
  Future<void> saveMessage(
    ChatMessage message, {
    required String conversationId,
  }) async {
    pending.add(message);
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(
    String conversationId, {
    int limit = 100,
    int offset = 0,
  }) async => pending;

  @override
  Future<List<ChatMessage>> getPendingMessages({int limit = 50}) async =>
      List.from(pending);

  @override
  Future<void> updateMessageStatus(
    String messageId,
    ChatMessageStatus status,
  ) async {
    updatedStatuses[messageId] = status;
    final index = pending.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      pending[index] = pending[index].copyWith(status: status);
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(
    String conversationId,
  ) => Stream.value(pending);

  @override
  Future<void> deleteMessagesForConversation(String conversationId) async {
    pending.clear();
  }
}

class _MockDirectMessageService implements DirectMessageService {
  final List<ChatMessage> retriedMessages = [];
  bool shouldFail = false;

  @override
  Future<void> retryMessage({
    required ChatMessage message,
    String? peerId,
  }) async {
    if (shouldFail) throw StateError('Send failed');
    retriedMessages.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PendingMessageRecoveryService', () {
    late _MockMessageRepo repository;
    late _MockDirectMessageService messageService;
    late PendingMessageRecoveryService recoveryService;

    setUp(() {
      repository = _MockMessageRepo();
      messageService = _MockDirectMessageService();
      recoveryService = PendingMessageRecoveryService(
        messageService: messageService,
        messageRepository: repository,
        ackTimeout: const Duration(milliseconds: 50),
        maxRetries: 2,
        checkInterval: const Duration(milliseconds: 100),
      );
    });

    tearDown(() {
      recoveryService.dispose();
    });

    test('skips recently sent messages within ackTimeout', () async {
      repository.pending.add(
        ChatMessage(
          id: 'msg-recent',
          conversationId: 'peer-1',
          senderNodeId: 'node-local',
          recipientNodeId: 'peer-1',
          content: 'Hello',
          timestamp: DateTime.now().toUtc(),
          isOutgoing: true,
          status: ChatMessageStatus.sent,
        ),
      );

      final retried = await recoveryService.processPendingMessages();
      expect(retried, equals(0));
      expect(messageService.retriedMessages, isEmpty);
    });

    test(
      'retries pending messages older than ackTimeout with original message ID',
      () async {
        final oldTimestamp = DateTime.now().toUtc().subtract(
          const Duration(milliseconds: 100),
        );

        repository.pending.add(
          ChatMessage(
            id: 'msg-unacked-1',
            conversationId: 'peer-1',
            senderNodeId: 'node-local',
            recipientNodeId: 'peer-1',
            content: 'Unacknowledged payload',
            timestamp: oldTimestamp,
            isOutgoing: true,
            status: ChatMessageStatus.sent,
          ),
        );

        final retried = await recoveryService.processPendingMessages();
        expect(retried, equals(1));
        expect(messageService.retriedMessages, hasLength(1));
        expect(
          messageService.retriedMessages.first.id,
          equals('msg-unacked-1'),
        );
        expect(recoveryService.getRetryCount('msg-unacked-1'), equals(1));
      },
    );

    test('marks message failed when maxRetries threshold is reached', () async {
      final oldTimestamp = DateTime.now().toUtc().subtract(
        const Duration(milliseconds: 100),
      );

      repository.pending.add(
        ChatMessage(
          id: 'msg-permanent-fail',
          conversationId: 'peer-1',
          senderNodeId: 'node-local',
          recipientNodeId: 'peer-1',
          content: 'Will fail permanently',
          timestamp: oldTimestamp,
          isOutgoing: true,
          status: ChatMessageStatus.sent,
        ),
      );

      // Attempt 1
      await recoveryService.processPendingMessages();
      expect(recoveryService.getRetryCount('msg-permanent-fail'), equals(1));

      // Attempt 2
      await recoveryService.processPendingMessages();
      expect(recoveryService.getRetryCount('msg-permanent-fail'), equals(2));

      // Attempt 3: exceeds maxRetries (2) -> marks failed
      await recoveryService.processPendingMessages();
      expect(
        repository.updatedStatuses['msg-permanent-fail'],
        equals(ChatMessageStatus.failed),
      );
    });
  });
}
