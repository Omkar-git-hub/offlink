// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:flutter/widgets.dart';

import '../../bluetooth/adaptive_ble_discovery.dart';
import '../lifecycle/app_lifecycle_manager.dart';
import 'battery_mode.dart';

/// Central coordinator managing Offlink power policies across BLE discovery,
/// connection management, message queue retries, and background operations.
class AdaptivePowerCoordinator {
  AdaptivePowerCoordinator({
    required AppLifecycleManager lifecycleManager,
    AdaptiveBleDiscovery? discovery,
    List<String> Function()? getConnectedPeerIds,
    int Function()? getPendingMessageCount,
    bool Function()? hasActiveLiveLocation,
  }) : _lifecycleManager = lifecycleManager,
       _discovery = discovery,
       _getConnectedPeerIds = getConnectedPeerIds,
       _getPendingMessageCount = getPendingMessageCount,
       _hasActiveLiveLocation = hasActiveLiveLocation {
    _lifecycleSubscription = _lifecycleManager.lifecycleChanges.listen(
      _handleLifecycleChange,
    );
  }

  final AppLifecycleManager _lifecycleManager;
  final AdaptiveBleDiscovery? _discovery;
  final List<String> Function()? _getConnectedPeerIds;
  final int Function()? _getPendingMessageCount;
  final bool Function()? _hasActiveLiveLocation;

  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  BatteryMode _currentMode = BatteryMode.active;
  bool _isBackgrounded = false;

  final StreamController<BatteryMode> _modeChangesController =
      StreamController<BatteryMode>.broadcast();

  /// Current battery optimization mode.
  BatteryMode get currentMode => _currentMode;

  /// Stream of battery mode transitions.
  Stream<BatteryMode> get modeChanges => _modeChangesController.stream;

  /// Current battery policy corresponding to the active mode.
  BatteryOptimizationPolicy get currentPolicy => policyForMode(_currentMode);

  /// Maps a [BatteryMode] to its default [BatteryOptimizationPolicy].
  static BatteryOptimizationPolicy policyForMode(BatteryMode mode) {
    switch (mode) {
      case BatteryMode.active:
        return BatteryOptimizationPolicy.active();
      case BatteryMode.balanced:
        return BatteryOptimizationPolicy.balanced();
      case BatteryMode.lowPower:
        return BatteryOptimizationPolicy.lowPower();
      case BatteryMode.conserve:
        return BatteryOptimizationPolicy.conserve();
    }
  }

  /// Evaluates device, network, and application state to transition to the optimal [BatteryMode].
  void evaluatePowerState() {
    BatteryMode newMode;

    if (_isBackgrounded) {
      newMode = BatteryMode.lowPower;
    } else {
      final connectedPeers = _getConnectedPeerIds?.call() ?? <String>[];
      final pendingCount = _getPendingMessageCount?.call() ?? 0;
      final activeLocation = _hasActiveLiveLocation?.call() ?? false;

      if (pendingCount > 0 || activeLocation) {
        // High priority activity in progress: active discovery and rapid cycles
        newMode = BatteryMode.active;
      } else if (connectedPeers.isNotEmpty) {
        // Connected mesh peers active and idle: balanced duty cycle
        newMode = BatteryMode.balanced;
      } else {
        // Foreground discovery with no peers yet
        newMode = BatteryMode.active;
      }
    }

    if (newMode != _currentMode) {
      _currentMode = newMode;
      _modeChangesController.add(_currentMode);
      _discovery?.updatePolicy(policyForMode(_currentMode));
    }
  }

  /// Explicitly transition to a user-configured or enforced [BatteryMode].
  void setMode(BatteryMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _modeChangesController.add(_currentMode);
      _discovery?.updatePolicy(policyForMode(_currentMode));
    }
  }

  /// Explicitly triggers foreground power evaluation.
  void onAppForegrounded() {
    _isBackgrounded = false;
    evaluatePowerState();
  }

  /// Explicitly triggers background power evaluation.
  void onAppBackgrounded() {
    _isBackgrounded = true;
    evaluatePowerState();
  }

  void _handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onAppForegrounded();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        onAppBackgrounded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void dispose() {
    _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
    _modeChangesController.close();
  }
}
