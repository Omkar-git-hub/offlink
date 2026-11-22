// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math';

import '../../bluetooth/ble_models.dart';
import '../../bluetooth/connection.dart';

enum RecoveryEventType {
  scheduled,
  attemptStarted,
  succeeded,
  failedAttempt,
  maxAttemptsReached,
  cancelled,
  paused,
  resumed,
}

class RecoveryEvent {
  const RecoveryEvent({
    required this.peerId,
    required this.type,
    this.attempt = 0,
    this.delay,
    this.error,
  });

  final String peerId;
  final RecoveryEventType type;
  final int attempt;
  final Duration? delay;
  final Object? error;
}

class ConnectionRecoveryCoordinator {
  ConnectionRecoveryCoordinator({
    required BleConnection connection,
    this.maxAttempts = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    Duration? minAttemptSpacing,
    this.backgroundMaxAttempts = 3,
    this.backgroundInitialDelay = const Duration(seconds: 5),
    Random? random,
  }) : _connection = connection,
       minAttemptSpacing =
           minAttemptSpacing ??
           (initialDelay < const Duration(milliseconds: 100)
               ? Duration.zero
               : const Duration(milliseconds: 500)),
       _random = random ?? Random();

  final BleConnection _connection;
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration minAttemptSpacing;
  final int backgroundMaxAttempts;
  final Duration backgroundInitialDelay;
  final Random _random;

  final Map<String, BlePeer> _trackedPeers = <String, BlePeer>{};
  final Map<String, int> _attempts = <String, int>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Set<String> _inFlightConnects = <String>{};

  bool _isBluetoothEnabled = true;
  bool _isBackgrounded = false;
  DateTime? _lastAttemptTimestamp;

  bool get isBackgrounded => _isBackgrounded;

  void setBackgroundState(bool isBackgrounded) {
    _isBackgrounded = isBackgrounded;
  }

  final StreamController<RecoveryEvent> _eventController =
      StreamController<RecoveryEvent>.broadcast();

  Stream<RecoveryEvent> get recoveryEvents => _eventController.stream;

  Set<String> get trackedPeerIds => _trackedPeers.keys.toSet();

  bool isReconnecting(String peerId) =>
      _retryTimers.containsKey(peerId) || _inFlightConnects.contains(peerId);

  int getRetryAttempt(String peerId) => _attempts[peerId] ?? 0;

  void trackPeer(BlePeer peer) {
    _trackedPeers[peer.peerId] = peer;
  }

  void untrackPeer(String peerId) {
    cancelRecovery(peerId);
    _trackedPeers.remove(peerId);
  }

  void onPeerConnected(String peerId) {
    _attempts.remove(peerId);
    _retryTimers.remove(peerId)?.cancel();
    _inFlightConnects.remove(peerId);
    _eventController.add(
      RecoveryEvent(peerId: peerId, type: RecoveryEventType.succeeded),
    );
  }

  void onPeerDisconnected(String peerId) {
    final peer = _trackedPeers[peerId];
    if (peer == null) return;
    if (_retryTimers.containsKey(peerId) ||
        _inFlightConnects.contains(peerId)) {
      return; // Already scheduled or in flight
    }

    scheduleReconnect(peer);
  }

  void scheduleReconnect(BlePeer peer) {
    if (!_isBluetoothEnabled) {
      _eventController.add(
        RecoveryEvent(peerId: peer.peerId, type: RecoveryEventType.paused),
      );
      return;
    }

    final effectiveMaxAttempts = _isBackgrounded
        ? backgroundMaxAttempts
        : maxAttempts;
    final currentAttempt = (_attempts[peer.peerId] ?? 0) + 1;
    if (currentAttempt > effectiveMaxAttempts) {
      _eventController.add(
        RecoveryEvent(
          peerId: peer.peerId,
          type: RecoveryEventType.maxAttemptsReached,
          attempt: currentAttempt - 1,
        ),
      );
      return;
    }

    _attempts[peer.peerId] = currentAttempt;

    final effectiveInitialDelay = _isBackgrounded
        ? backgroundInitialDelay
        : initialDelay;
    // Exponential backoff: effectiveInitialDelay * (backoffMultiplier ^ (attempt - 1)) + jitter
    final exponent = pow(backoffMultiplier, currentAttempt - 1).toDouble();
    final baseMillis = (effectiveInitialDelay.inMilliseconds * exponent)
        .toInt();
    final cappedMillis = min(baseMillis, maxDelay.inMilliseconds);
    // Add 10% random jitter to avoid synchronization storms
    final jitter = _random.nextInt(max(1, (cappedMillis * 0.1).toInt()));
    final delay = Duration(milliseconds: cappedMillis + jitter);

    _eventController.add(
      RecoveryEvent(
        peerId: peer.peerId,
        type: RecoveryEventType.scheduled,
        attempt: currentAttempt,
        delay: delay,
      ),
    );

    _retryTimers[peer.peerId]?.cancel();
    _retryTimers[peer.peerId] = Timer(delay, () => _executeReconnect(peer));
  }

  Future<void> _executeReconnect(BlePeer peer) async {
    _retryTimers.remove(peer.peerId);
    if (!_trackedPeers.containsKey(peer.peerId) || !_isBluetoothEnabled) {
      return;
    }

    // Ensure minimum spacing between successive connection attempts across peers
    if (minAttemptSpacing > Duration.zero && _lastAttemptTimestamp != null) {
      final elapsed = DateTime.now().difference(_lastAttemptTimestamp!);
      if (elapsed < minAttemptSpacing) {
        final waitDuration = minAttemptSpacing - elapsed;
        await Future<void>.delayed(waitDuration);
        if (!_trackedPeers.containsKey(peer.peerId) || !_isBluetoothEnabled) {
          return;
        }
      }
    }
    _lastAttemptTimestamp = DateTime.now();

    _inFlightConnects.add(peer.peerId);
    _eventController.add(
      RecoveryEvent(
        peerId: peer.peerId,
        type: RecoveryEventType.attemptStarted,
        attempt: _attempts[peer.peerId] ?? 1,
      ),
    );

    try {
      await _connection.connect(peer);
      onPeerConnected(peer.peerId);
    } catch (error) {
      _inFlightConnects.remove(peer.peerId);
      _eventController.add(
        RecoveryEvent(
          peerId: peer.peerId,
          type: RecoveryEventType.failedAttempt,
          attempt: _attempts[peer.peerId] ?? 1,
          error: error,
        ),
      );
      // Reschedule next attempt
      if (_trackedPeers.containsKey(peer.peerId)) {
        scheduleReconnect(peer);
      }
    }
  }

  void cancelRecovery(String peerId) {
    _retryTimers.remove(peerId)?.cancel();
    _inFlightConnects.remove(peerId);
    _attempts.remove(peerId);
    _eventController.add(
      RecoveryEvent(peerId: peerId, type: RecoveryEventType.cancelled),
    );
  }

  void onBluetoothStateChanged(bool isEnabled) {
    _isBluetoothEnabled = isEnabled;
    if (!isEnabled) {
      // Pause all timers
      for (final timer in _retryTimers.values) {
        timer.cancel();
      }
      _retryTimers.clear();
      for (final peerId in _trackedPeers.keys) {
        _eventController.add(
          RecoveryEvent(peerId: peerId, type: RecoveryEventType.paused),
        );
      }
    } else {
      // Resume retries immediately for tracked peers not connected
      for (final peer in _trackedPeers.values) {
        _eventController.add(
          RecoveryEvent(peerId: peer.peerId, type: RecoveryEventType.resumed),
        );
        scheduleReconnect(peer);
      }
    }
  }

  void dispose() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _trackedPeers.clear();
    _attempts.clear();
    _inFlightConnects.clear();
    _eventController.close();
  }
}
