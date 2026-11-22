import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/adaptive_ble_discovery.dart';
import 'package:offlink/bluetooth/ble_discovery_event.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/discovery.dart';
import 'package:offlink/domain/battery/adaptive_power_coordinator.dart';
import 'package:offlink/domain/battery/battery_mode.dart';
import 'package:offlink/domain/lifecycle/app_lifecycle_manager.dart';

class _FakeDiscovery implements BleDiscovery {
  bool isScanning = false;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<BlePeer> get discoveredPeers => const Stream.empty();
  @override
  Stream<BleDiscoveryEvent> get discoveryEvents => const Stream.empty();
  @override
  Future<void> startScanning() async {
    isScanning = true;
    startCalls++;
  }

  @override
  Future<void> stopScanning() async {
    isScanning = false;
    stopCalls++;
  }

  @override
  Future<void> startAdvertising() async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<Set<String>> completeScanCycle() async => const {};
  void dispose() {}
}

void main() {
  group('AdaptivePowerCoordinator', () {
    late AppLifecycleManager lifecycleManager;
    late _FakeDiscovery fakeDiscovery;
    late AdaptiveBleDiscovery adaptiveDiscovery;
    late List<String> connectedPeers;
    late int pendingMessageCount;
    late bool hasActiveLiveLocation;
    late AdaptivePowerCoordinator coordinator;

    setUp(() {
      lifecycleManager = AppLifecycleManager();
      fakeDiscovery = _FakeDiscovery();
      adaptiveDiscovery = AdaptiveBleDiscovery(underlying: fakeDiscovery);
      connectedPeers = [];
      pendingMessageCount = 0;
      hasActiveLiveLocation = false;

      coordinator = AdaptivePowerCoordinator(
        lifecycleManager: lifecycleManager,
        discovery: adaptiveDiscovery,
        getConnectedPeerIds: () => connectedPeers,
        getPendingMessageCount: () => pendingMessageCount,
        hasActiveLiveLocation: () => hasActiveLiveLocation,
      );
    });

    tearDown(() {
      coordinator.dispose();
      adaptiveDiscovery.dispose();
      lifecycleManager.dispose();
    });

    test('initializes with active mode', () {
      expect(coordinator.currentMode, equals(BatteryMode.active));
      expect(coordinator.currentPolicy.mode, equals(BatteryMode.active));
    });

    test(
      'transitions to lowPower on app backgrounding and updates discovery policy',
      () async {
        final modes = <BatteryMode>[];
        final sub = coordinator.modeChanges.listen(modes.add);

        lifecycleManager.handleLifecycleChange(AppLifecycleState.paused);
        await Future<void>.delayed(Duration.zero);

        expect(coordinator.currentMode, equals(BatteryMode.lowPower));
        expect(adaptiveDiscovery.policy.mode, equals(BatteryMode.lowPower));
        expect(modes, contains(BatteryMode.lowPower));

        await sub.cancel();
      },
    );

    test(
      'transitions to balanced when peers are connected and idle in foreground',
      () async {
        connectedPeers.add('peer-1');
        pendingMessageCount = 0;
        hasActiveLiveLocation = false;

        coordinator.evaluatePowerState();

        expect(coordinator.currentMode, equals(BatteryMode.balanced));
        expect(adaptiveDiscovery.policy.mode, equals(BatteryMode.balanced));
      },
    );

    test(
      'maintains active mode when pending messages exist even if peers connected',
      () async {
        connectedPeers.add('peer-1');
        pendingMessageCount = 3;
        hasActiveLiveLocation = false;

        coordinator.evaluatePowerState();

        expect(coordinator.currentMode, equals(BatteryMode.active));
        expect(adaptiveDiscovery.policy.mode, equals(BatteryMode.active));
      },
    );

    test('maintains active mode when live location is active', () async {
      connectedPeers.add('peer-1');
      pendingMessageCount = 0;
      hasActiveLiveLocation = true;

      coordinator.evaluatePowerState();

      expect(coordinator.currentMode, equals(BatteryMode.active));
    });

    test('setMode manually updates mode and discovery policy', () {
      coordinator.setMode(BatteryMode.conserve);

      expect(coordinator.currentMode, equals(BatteryMode.conserve));
      expect(adaptiveDiscovery.policy.mode, equals(BatteryMode.conserve));
      expect(adaptiveDiscovery.policy.dutyCycleRatio, closeTo(4 / 124, 0.001));
    });
  });
}
