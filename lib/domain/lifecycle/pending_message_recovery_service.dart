// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import '../messaging/chat_message.dart';
import '../messaging/direct_message_service.dart';
import '../messaging/message_repository.dart';

/// Service responsible for managing offline outgoing messages,
/// retrying unacknowledged messages with exponential backoff and randomized jitter,
/// enforcing queue storage bounds, expiring stale messages, and recovering pending delivery state.
class PendingMessageRecoveryService {
  PendingMessageRecoveryService({
    required DirectMessageService messageService,
    required MessageRepository messageRepository,
    this.ackTimeout = const Duration(seconds: 5),
    this.maxRetries = 5,
    this.checkInterval = const Duration(seconds: 10),
    this.maxMessageAge = const Duration(hours: 24),
    this.maxQueueSize = 500,
    Duration? initialBackoff,
    this.maxBackoff = const Duration(minutes: 5),
    Random? random,
  }) : _messageService = messageService,
       _messageRepository = messageRepository,
       initialBackoff =
           initialBackoff ??
           (ackTimeout < const Duration(seconds: 1)
               ? Duration.zero
               : const Duration(seconds: 2)),
       _random = random ?? Random();

  final DirectMessageService _messageService;
  final MessageRepository _messageRepository;
  final Duration ackTimeout;
  final int maxRetries;
  final Duration checkInterval;
  final Duration maxMessageAge;
  final int maxQueueSize;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final Random _random;

  final Map<String, int> _retryCounts = <String, int>{};
  final Map<String, DateTime> _nextAttemptAt = <String, DateTime>{};
  Timer? _periodicTimer;
  bool _isProcessing = false;

  int getRetryCount(String messageId) => _retryCounts[messageId] ?? 0;

  DateTime? getNextAttemptAt(String messageId) => _nextAttemptAt[messageId];

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

  /// Triggers an immediate retry flush for unacknowledged messages
  /// targeting a newly connected or discovered [recipientNodeId].
  Future<int> onPeerOrRouteAvailable(String recipientNodeId) async {
    return await processPendingMessages(targetRecipientNodeId: recipientNodeId);
  }

  /// Scans and retries pending unacknowledged outgoing messages.
  Future<int> processPendingMessages({String? targetRecipientNodeId}) async {
    if (_isProcessing) return 0;
    _isProcessing = true;

    var retriedCount = 0;
    try {
      // 1. Prune expired unacknowledged messages older than maxMessageAge
      await _messageRepository.pruneExpiredMessages(maxAge: maxMessageAge);

      // 2. Query bounded list of pending outgoing messages
      final pending = await _messageRepository.getPendingMessages(
        limit: maxQueueSize,
      );
      final now = DateTime.now().toUtc();

      for (final message in pending) {
        // Filter by recipient if targeted flush
        if (targetRecipientNodeId != null &&
            message.recipientNodeId != targetRecipientNodeId) {
          continue;
        }

        // Expiration check
        if (now.difference(message.timestamp) > maxMessageAge) {
          await _messageRepository.updateMessageStatus(
            message.id,
            ChatMessageStatus.failed,
          );
          clearMessageTracking(message.id);
          continue;
        }

        // Skip if message was sent too recently (within ackTimeout)
        if (now.difference(message.timestamp) < ackTimeout) {
          continue;
        }

        // Backoff check: skip if not yet due for next retry
        final scheduled = _nextAttemptAt[message.id];
        if (scheduled != null && now.isBefore(scheduled)) {
          continue;
        }

        final currentCount = (_retryCounts[message.id] ?? 0) + 1;
        _retryCounts[message.id] = currentCount;

        if (currentCount > maxRetries) {
          await _messageRepository.updateMessageStatus(
            message.id,
            ChatMessageStatus.failed,
          );
          clearMessageTracking(message.id);
          continue;
        }

        // Schedule next attempt with exponential backoff & jitter
        final delay = _calculateBackoffWithJitter(currentCount);
        _nextAttemptAt[message.id] = now.add(delay);

        try {
          await _messageService.retryMessage(message: message);
          retriedCount++;
        } catch (_) {
          // Failure to resend: will retry next scheduled backoff cycle
        }
      }
    } finally {
      _isProcessing = false;
    }

    return retriedCount;
  }

  Duration _calculateBackoffWithJitter(int attempt) {
    // Exponential backoff: initialBackoff * 2^(attempt - 1)
    final expMs = initialBackoff.inMilliseconds * pow(2, attempt - 1);
    final cappedMs = min(
      expMs.toDouble(),
      maxBackoff.inMilliseconds.toDouble(),
    );
    // Randomized jitter: +/- 20%
    final jitterFactor = 0.8 + (_random.nextDouble() * 0.4);
    final totalMs = (cappedMs * jitterFactor).toInt();
    return Duration(milliseconds: totalMs);
  }

  void clearMessageTracking(String messageId) {
    _retryCounts.remove(messageId);
    _nextAttemptAt.remove(messageId);
  }

  void dispose() {
    stop();
    _retryCounts.clear();
    _nextAttemptAt.clear();
  }
}
