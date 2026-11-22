// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../bluetooth/adaptive_ble_discovery.dart';
import '../../bluetooth/discovery.dart';
import '../battery/adaptive_power_coordinator.dart';
import '../battery/battery_mode.dart';
import '../queue/store_and_forward_manager.dart';
import 'app_lifecycle_manager.dart';
import 'background_service_contract.dart';
import 'connection_recovery_coordinator.dart';
import 'pending_message_recovery_service.dart';

class AppLifecycleCoordinator {
  AppLifecycleCoordinator({
    required AppLifecycleManager lifecycleManager,
    required BackgroundServiceContract backgroundService,
    required ConnectionRecoveryCoordinator connectionRecovery,
    required PendingMessageRecoveryService pendingMessageRecovery,
    StoreAndForwardManager? storeAndForwardManager,
    BleDiscovery? discovery,
    AdaptivePowerCoordinator? powerCoordinator,
  }) : _lifecycleManager = lifecycleManager,
       _backgroundService = backgroundService,
       _connectionRecovery = connectionRecovery,
       _pendingMessageRecovery = pendingMessageRecovery,
       _storeAndForwardManager = storeAndForwardManager,
       _discovery = discovery,
       _powerCoordinator = powerCoordinator {
    _subscription = _lifecycleManager.lifecycleChanges.listen(
      _handleLifecycleTransition,
    );
  }

  final AppLifecycleManager _lifecycleManager;
  final BackgroundServiceContract _backgroundService;
  final ConnectionRecoveryCoordinator _connectionRecovery;
  final PendingMessageRecoveryService _pendingMessageRecovery;
  final StoreAndForwardManager? _storeAndForwardManager;
  final BleDiscovery? _discovery;
  final AdaptivePowerCoordinator? _powerCoordinator;

  StreamSubscription<AppLifecycleState>? _subscription;
  bool _isBackgroundServiceActive = false;

  AppLifecycleManager get lifecycleManager => _lifecycleManager;
  BackgroundServiceContract get backgroundService => _backgroundService;
  ConnectionRecoveryCoordinator get connectionRecovery => _connectionRecovery;
  PendingMessageRecoveryService get pendingMessageRecovery =>
      _pendingMessageRecovery;
  StoreAndForwardManager? get storeAndForwardManager => _storeAndForwardManager;
  AdaptivePowerCoordinator? get powerCoordinator => _powerCoordinator;
  bool get isBackgroundServiceActive => _isBackgroundServiceActive;

  void initialize() {
    _lifecycleManager.startObserving();
    _pendingMessageRecovery.start();
    _storeAndForwardManager?.start();
  }

  Future<void> _handleLifecycleTransition(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await _onAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        await _onAppBackgrounded();
        break;
      case AppLifecycleState.inactive:
        // Transitionary state: keep state intact without altering execution
        break;
      case AppLifecycleState.detached:
        await _onAppDetached();
        break;
    }
  }

  Future<void> _onAppResumed() async {
    // When returning to foreground:
    // 1. Process pending unacknowledged messages
    await _pendingMessageRecovery.processPendingMessages();

    // 2. Process store and forward queue
    await _storeAndForwardManager?.processStoreAndForward();

    // 3. Inform connection recovery of foreground state
    _connectionRecovery.setBackgroundState(false);

    // 4. Update power mode and discovery policy
    final powerCoordinator = _powerCoordinator;
    final discovery = _discovery;
    if (powerCoordinator != null) {
      powerCoordinator.onAppForegrounded();
    } else if (discovery is AdaptiveBleDiscovery) {
      discovery.updatePolicy(BatteryOptimizationPolicy.active());
    }

    // 5. Ensure discovery scanning is restarted if stopped
    if (discovery != null) {
      try {
        await discovery.startScanning();
      } catch (_) {
        // Safe fallback if Bluetooth unavailable
      }
    }
  }

  Future<void> _onAppBackgrounded() async {
    // When entering background:
    // 1. Start foreground service to maintain Android process & BLE execution
    try {
      _isBackgroundServiceActive = await _backgroundService.startService(
        title: 'Offlink Mesh Active',
        message: 'Maintaining offline peer-to-peer BLE messaging',
      );
    } catch (_) {
      _isBackgroundServiceActive = false;
    }

    // 2. Inform connection recovery of background state
    _connectionRecovery.setBackgroundState(true);

    // 3. Update power mode and discovery policy
    final powerCoordinator = _powerCoordinator;
    final discovery = _discovery;
    if (powerCoordinator != null) {
      powerCoordinator.onAppBackgrounded();
    } else if (discovery is AdaptiveBleDiscovery) {
      discovery.updatePolicy(BatteryOptimizationPolicy.lowPower());
    } else if (discovery != null) {
      // Legacy fallback: stop continuous scanning in background
      try {
        await discovery.stopScanning();
      } catch (_) {}
    }
  }

  Future<void> _onAppDetached() async {
    try {
      await _backgroundService.stopService();
      _isBackgroundServiceActive = false;
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pendingMessageRecovery.dispose();
    _connectionRecovery.dispose();
    _storeAndForwardManager?.dispose();
    _powerCoordinator?.dispose();
    _lifecycleManager.dispose();
  }
}
