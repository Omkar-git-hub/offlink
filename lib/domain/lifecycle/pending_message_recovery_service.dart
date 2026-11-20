// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../messaging/chat_message.dart';
import '../messaging/direct_message_service.dart';
import '../messaging/message_repository.dart';

class PendingMessageRecoveryService {
  PendingMessageRecoveryService({
    required DirectMessageService messageService,
    required MessageRepository messageRepository,
    this.ackTimeout = const Duration(seconds: 5),
    this.maxRetries = 3,
    this.checkInterval = const Duration(seconds: 10),
  }) : _messageService = messageService,
       _messageRepository = messageRepository;

  final DirectMessageService _messageService;
  final MessageRepository _messageRepository;
  final Duration ackTimeout;
  final int maxRetries;
  final Duration checkInterval;

  final Map<String, int> _retryCounts = <String, int>{};
  Timer? _periodicTimer;
  bool _isProcessing = false;

  int getRetryCount(String messageId) => _retryCounts[messageId] ?? 0;

  void start() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(checkInterval, (_) {
      processPendingMessages();
    });
  }

  void stop() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<int> processPendingMessages() async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    var retriedCount = 0;
    try {
      final pending = await _messageRepository.getPendingMessages();
      final now = DateTime.now().toUtc();

      for (final message in pending) {
        // Skip if message was sent too recently (within ackTimeout)
        if (now.difference(message.timestamp) < ackTimeout) {
          continue;
        }

        final currentCount = (_retryCounts[message.id] ?? 0) + 1;
        _retryCounts[message.id] = currentCount;

        if (currentCount > maxRetries) {
          await _messageRepository.updateMessageStatus(
            message.id,
            ChatMessageStatus.failed,
          );
          _retryCounts.remove(message.id);
          continue;
        }

        try {
          await _messageService.retryMessage(message: message);
          retriedCount++;
        } catch (_) {
          // Failure to resend: will retry next cycle until maxRetries reached
        }
      }
    } finally {
      _isProcessing = false;
    }

    return retriedCount;
  }

  void clearMessageTracking(String messageId) {
    _retryCounts.remove(messageId);
  }

  void dispose() {
    stop();
    _retryCounts.clear();
  }
}
