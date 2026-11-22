// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../domain/battery/battery_mode.dart';
import 'ble_discovery_event.dart';
import 'ble_models.dart';
import 'discovery.dart';

/// Decorator implementation of [BleDiscovery] providing adaptive duty-cycled scanning.
///
/// Rather than scanning continuously (100% radio on-time), [AdaptiveBleDiscovery]
/// alternates between active scan windows (e.g. 8s) and resting pause windows (e.g. 4s)
/// according to the active [BatteryOptimizationPolicy].
///
/// Key capabilities:
/// - Significantly cuts BLE radio power draw by 33% to 94% depending on mode.
/// - Automatically completes scan cycles at the end of each scan window to prune lost peers.
/// - Retains peripheral advertising during scan pause windows so other nodes can still connect.
/// - Supports immediate scan triggering upon user interaction or queued outgoing messages.
class AdaptiveBleDiscovery implements BleDiscovery {
  AdaptiveBleDiscovery({
    required BleDiscovery underlying,
    BatteryOptimizationPolicy? initialPolicy,
  }) : _underlying = underlying,
       _policy = initialPolicy ?? BatteryOptimizationPolicy.active();

  final BleDiscovery _underlying;
  BatteryOptimizationPolicy _policy;

  Timer? _cycleTimer;
  bool _isCycleActive = false;
  bool _isInScanPhase = false;
  bool _isDisposed = false;
  int _completedCycles = 0;

  final StreamController<BatteryOptimizationPolicy> _policyChangesController =
      StreamController<BatteryOptimizationPolicy>.broadcast();

  /// Current battery optimization policy governing duty cycles.
  BatteryOptimizationPolicy get policy => _policy;

  /// Stream of policy transitions.
  Stream<BatteryOptimizationPolicy> get policyChanges =>
      _policyChangesController.stream;

  /// Whether the adaptive discovery loop is active.
  bool get isScanning => _isCycleActive;

  /// Whether the radio is currently in an active scan window (versus pause window).
  bool get isInScanPhase => _isInScanPhase;

  /// Total number of completed scan cycles.
  int get completedCycles => _completedCycles;

  /// Updates the active battery policy and adjusts duty cycle timing immediately.
  void updatePolicy(BatteryOptimizationPolicy newPolicy) {
    if (_isDisposed) return;
    _policy = newPolicy;
    _policyChangesController.add(_policy);

    // If currently cycling, restart the cycle with the new policy timings
    if (_isCycleActive) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      if (_isInScanPhase) {
        // Schedule completion according to new scan duration or finish now
        _cycleTimer = Timer(_policy.scanDuration, _onScanWindowFinished);
      } else {
        // In pause phase: apply new pause duration
        _cycleTimer = Timer(_policy.pauseDuration, _enterScanWindow);
      }
    }
  }

  @override
  Stream<BlePeer> get discoveredPeers => _underlying.discoveredPeers;

  @override
  Stream<BleDiscoveryEvent> get discoveryEvents => _underlying.discoveryEvents;

  @override
  Future<void> startScanning() async {
    if (_isDisposed || _isCycleActive) {
      return;
    }

    _isCycleActive = true;
    await _enterScanWindow();
  }

  @override
  Future<void> stopScanning() async {
    _isCycleActive = false;
    _cycleTimer?.cancel();
    _cycleTimer = null;

    if (_isInScanPhase) {
      _isInScanPhase = false;
      try {
        await _underlying.stopScanning();
      } catch (_) {}
    }
  }

  @override
  Future<void> startAdvertising() => _underlying.startAdvertising();

  @override
  Future<void> stopAdvertising() => _underlying.stopAdvertising();

  @override
  Future<Set<String>> completeScanCycle() => _underlying.completeScanCycle();

  /// Immediately interrupts any resting pause phase to begin an active scan window.
  /// Used when user pulls to refresh or when a new high-priority message is enqueued.
  Future<void> triggerImmediateScan() async {
    if (_isDisposed) return;

    if (!_isCycleActive) {
      await startScanning();
      return;
    }

    // If currently resting in a pause phase, immediately switch to scan window
    if (!_isInScanPhase) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      await _enterScanWindow();
    }
  }

  Future<void> _enterScanWindow() async {
    if (_isDisposed || !_isCycleActive) return;

    _isInScanPhase = true;
    try {
      await _underlying.startScanning();
    } catch (_) {
      // Safe fallback if Bluetooth radio state is transitional
    }

    _cycleTimer?.cancel();
    _cycleTimer = Timer(_policy.scanDuration, _onScanWindowFinished);
  }

  Future<void> _onScanWindowFinished() async {
    if (_isDisposed || !_isCycleActive) return;

    _isInScanPhase = false;
    try {
      await _underlying.stopScanning();
      await _underlying.completeScanCycle();
    } catch (_) {}

    _completedCycles++;

    if (!_isCycleActive) return;

    // Transition into pause window
    _cycleTimer?.cancel();
    _cycleTimer = Timer(_policy.pauseDuration, _enterScanWindow);
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await stopScanning();
    try {
      await stopAdvertising();
    } catch (_) {}
    await _policyChangesController.close();
  }
}
