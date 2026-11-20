import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/connection.dart';
import 'package:offlink/domain/lifecycle/connection_recovery_coordinator.dart';

class _FakeBleConnection implements BleConnection {
  final List<String> connectCalls = [];
  final List<String> disconnectCalls = [];
  final StreamController<BleConnectionState> _controller =
      StreamController<BleConnectionState>.broadcast();

  bool shouldFail = false;

  @override
  Stream<BleConnectionState> get connectionStates => _controller.stream;

  @override
  Future<void> connect(BlePeer peer) async {
    connectCalls.add(peer.peerId);
    if (shouldFail) {
      throw StateError('Connection failed');
    }
  }

  @override
  Future<void> disconnect(String peerId) async {
    disconnectCalls.add(peerId);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('ConnectionRecoveryCoordinator', () {
    late _FakeBleConnection connection;
    late ConnectionRecoveryCoordinator coordinator;
    final testPeer = BlePeer(
      peerId: 'peer-test-1',
      displayName: 'Test Peer',
      signalStrength: -65,
    );

    setUp(() {
      connection = _FakeBleConnection();
      coordinator = ConnectionRecoveryCoordinator(
        connection: connection,
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 20),
        maxDelay: const Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
      );
    });

    tearDown(() {
      coordinator.dispose();
      connection.dispose();
    });

    test('tracks and untracks peers correctly', () {
      expect(coordinator.trackedPeerIds, isEmpty);

      coordinator.trackPeer(testPeer);
      expect(coordinator.trackedPeerIds, contains('peer-test-1'));

      coordinator.untrackPeer('peer-test-1');
      expect(coordinator.trackedPeerIds, isEmpty);
    });

    test(
      'schedules reconnect with exponential backoff on disconnect',
      () async {
        final events = <RecoveryEvent>[];
        final sub = coordinator.recoveryEvents.listen(events.add);

        coordinator.trackPeer(testPeer);
        coordinator.onPeerDisconnected('peer-test-1');

        expect(coordinator.isReconnecting('peer-test-1'), isTrue);
        expect(coordinator.getRetryAttempt('peer-test-1'), equals(1));

        // Wait for backoff timer to fire
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(connection.connectCalls, contains('peer-test-1'));
        expect(
          events.any((e) => e.type == RecoveryEventType.scheduled),
          isTrue,
        );
        expect(
          events.any((e) => e.type == RecoveryEventType.attemptStarted),
          isTrue,
        );
        expect(
          events.any((e) => e.type == RecoveryEventType.succeeded),
          isTrue,
        );
        expect(coordinator.isReconnecting('peer-test-1'), isFalse);

        await sub.cancel();
      },
    );

    test('retries on failed attempt up to maxAttempts', () async {
      connection.shouldFail = true;
      final events = <RecoveryEvent>[];
      final sub = coordinator.recoveryEvents.listen(events.add);

      coordinator.trackPeer(testPeer);
      coordinator.onPeerDisconnected('peer-test-1');

      // Wait for all 3 attempts to execute
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(connection.connectCalls.length, equals(3));
      expect(
        events.any((e) => e.type == RecoveryEventType.maxAttemptsReached),
        isTrue,
      );
      expect(coordinator.isReconnecting('peer-test-1'), isFalse);

      await sub.cancel();
    });

    test('cancels scheduled reconnect on manual untrack', () async {
      final events = <RecoveryEvent>[];
      final sub = coordinator.recoveryEvents.listen(events.add);

      coordinator.trackPeer(testPeer);
      coordinator.onPeerDisconnected('peer-test-1');
      expect(coordinator.isReconnecting('peer-test-1'), isTrue);

      coordinator.untrackPeer('peer-test-1');
      expect(coordinator.isReconnecting('peer-test-1'), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Should not have connected
      expect(connection.connectCalls, isEmpty);
      expect(events.any((e) => e.type == RecoveryEventType.cancelled), isTrue);

      await sub.cancel();
    });

    test(
      'pauses recovery when Bluetooth is disabled and resumes when enabled',
      () async {
        final events = <RecoveryEvent>[];
        final sub = coordinator.recoveryEvents.listen(events.add);

        coordinator.trackPeer(testPeer);
        coordinator.onBluetoothStateChanged(false);

        coordinator.onPeerDisconnected('peer-test-1');
        await Future<void>.delayed(Duration.zero);
        expect(events.any((e) => e.type == RecoveryEventType.paused), isTrue);
        expect(connection.connectCalls, isEmpty);

        // Re-enable Bluetooth
        coordinator.onBluetoothStateChanged(true);
        await Future<void>.delayed(Duration.zero);
        expect(events.any((e) => e.type == RecoveryEventType.resumed), isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(connection.connectCalls, contains('peer-test-1'));

        await sub.cancel();
      },
    );
  });
}
