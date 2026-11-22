import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/adaptive_ble_discovery.dart';
import 'package:offlink/bluetooth/ble_discovery_event.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/discovery.dart';
import 'package:offlink/domain/battery/battery_mode.dart';

class _FakeDiscovery implements BleDiscovery {
  int startScanCalls = 0;
  int stopScanCalls = 0;
  int completeCycleCalls = 0;
  int startAdvCalls = 0;
  int stopAdvCalls = 0;

  bool isScanning = false;
  bool isAdvertising = false;

  final StreamController<BlePeer> peerController =
      StreamController<BlePeer>.broadcast();
  final StreamController<BleDiscoveryEvent> eventController =
      StreamController<BleDiscoveryEvent>.broadcast();

  @override
  Stream<BlePeer> get discoveredPeers => peerController.stream;

  @override
  Stream<BleDiscoveryEvent> get discoveryEvents => eventController.stream;

  @override
  Future<void> startScanning() async {
    startScanCalls++;
    isScanning = true;
  }

  @override
  Future<void> stopScanning() async {
    stopScanCalls++;
    isScanning = false;
  }

  @override
  Future<Set<String>> completeScanCycle() async {
    completeCycleCalls++;
    return <String>{};
  }

  @override
  Future<void> startAdvertising() async {
    startAdvCalls++;
    isAdvertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    stopAdvCalls++;
    isAdvertising = false;
  }

  void dispose() {
    peerController.close();
    eventController.close();
  }
}

void main() {
  group('AdaptiveBleDiscovery', () {
    late _FakeDiscovery underlying;
    late AdaptiveBleDiscovery adaptiveDiscovery;

    setUp(() {
      underlying = _FakeDiscovery();
      adaptiveDiscovery = AdaptiveBleDiscovery(
        underlying: underlying,
        initialPolicy: const BatteryOptimizationPolicy(
          mode: BatteryMode.active,
          scanDuration: Duration(seconds: 2),
          pauseDuration: Duration(seconds: 1),
          maxReconnectAttempts: 5,
          reconnectInitialDelay: Duration(seconds: 1),
          locationUpdateInterval: Duration(seconds: 30),
        ),
      );
    });

    tearDown(() async {
      await adaptiveDiscovery.dispose();
      underlying.dispose();
    });

    test(
      'duty cycle: alternates between scanning and resting pause windows',
      () async {
        expect(adaptiveDiscovery.isScanning, isFalse);
        expect(adaptiveDiscovery.isInScanPhase, isFalse);

        // Start adaptive scanning
        await adaptiveDiscovery.startScanning();

        expect(adaptiveDiscovery.isScanning, isTrue);
        expect(adaptiveDiscovery.isInScanPhase, isTrue);
        expect(underlying.startScanCalls, equals(1));
        expect(underlying.stopScanCalls, equals(0));

        // Advance past scan duration (2s)
        await Future<void>.delayed(const Duration(milliseconds: 2050));

        // Radio scan stopped, cycle completed, now in pause phase (1s)
        expect(underlying.stopScanCalls, equals(1));
        expect(underlying.completeCycleCalls, equals(1));
        expect(adaptiveDiscovery.isInScanPhase, isFalse);
        expect(adaptiveDiscovery.isScanning, isTrue);
        expect(adaptiveDiscovery.completedCycles, equals(1));

        // Advance past pause duration (1s)
        await Future<void>.delayed(const Duration(milliseconds: 1050));

        // Next scan window started
        expect(underlying.startScanCalls, equals(2));
        expect(adaptiveDiscovery.isInScanPhase, isTrue);

        await adaptiveDiscovery.stopScanning();
        expect(adaptiveDiscovery.isScanning, isFalse);
        expect(adaptiveDiscovery.isInScanPhase, isFalse);
        expect(underlying.stopScanCalls, equals(2));
      },
    );

    test('triggerImmediateScan interrupts pause phase instantly', () async {
      await adaptiveDiscovery.startScanning();

      // Advance into pause window
      await Future<void>.delayed(const Duration(milliseconds: 2050));
      expect(adaptiveDiscovery.isInScanPhase, isFalse);
      expect(underlying.startScanCalls, equals(1));

      // Trigger immediate scan while resting in pause window
      await adaptiveDiscovery.triggerImmediateScan();

      // Immediately re-enters scan window without waiting for pause duration to finish
      expect(adaptiveDiscovery.isInScanPhase, isTrue);
      expect(underlying.startScanCalls, equals(2));
    });

    test(
      'updatePolicy dynamically updates cycle timings and notifies stream',
      () async {
        final emittedPolicies = <BatteryOptimizationPolicy>[];
        final sub = adaptiveDiscovery.policyChanges.listen(emittedPolicies.add);

        final lowPower = BatteryOptimizationPolicy.lowPower();
        adaptiveDiscovery.updatePolicy(lowPower);
        await Future<void>.delayed(Duration.zero);

        expect(adaptiveDiscovery.policy.mode, equals(BatteryMode.lowPower));
        expect(emittedPolicies, hasLength(1));
        expect(emittedPolicies.first.mode, equals(BatteryMode.lowPower));

        await sub.cancel();
      },
    );

    test('delegates advertising without interrupting scan cycle', () async {
      await adaptiveDiscovery.startAdvertising();
      expect(underlying.startAdvCalls, equals(1));

      await adaptiveDiscovery.stopAdvertising();
      expect(underlying.stopAdvCalls, equals(1));
    });
  });
}
