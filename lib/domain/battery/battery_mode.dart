/// Battery operation mode for adaptive BLE discovery, reconnection, and timers.
enum BatteryMode {
  /// Foreground active mode: user is actively navigating or chatting.
  /// Fast, responsive discovery with moderate duty cycling (e.g. 8s scan / 4s pause).
  active,

  /// Foreground balanced mode: app is open and connected to peers but idle.
  /// Reduced duty cycling (e.g. 6s scan / 12s pause) to conserve power.
  balanced,

  /// Background low-power mode: app is minimized/screen locked, running with
  /// Android foreground service. Minimal opportunistic scanning (e.g. 4s scan / 60s pause).
  lowPower,

  /// Conserve mode: no peers in vicinity or repeated failures.
  /// Heavily backed-off scanning (e.g. 4s scan / 120s pause with jitter).
  conserve,
}

/// Parameters governing adaptive scan duty cycles, reconnection caps, and timer behavior.
class BatteryOptimizationPolicy {
  const BatteryOptimizationPolicy({
    required this.mode,
    required this.scanDuration,
    required this.pauseDuration,
    required this.maxReconnectAttempts,
    required this.reconnectInitialDelay,
    required this.locationUpdateInterval,
    this.allowBackgroundScanning = true,
  });

  final BatteryMode mode;
  final Duration scanDuration;
  final Duration pauseDuration;
  final int maxReconnectAttempts;
  final Duration reconnectInitialDelay;
  final Duration locationUpdateInterval;
  final bool allowBackgroundScanning;

  /// Default active policy: responsive 8s scan / 4s pause window.
  factory BatteryOptimizationPolicy.active() {
    return const BatteryOptimizationPolicy(
      mode: BatteryMode.active,
      scanDuration: Duration(seconds: 8),
      pauseDuration: Duration(seconds: 4),
      maxReconnectAttempts: 5,
      reconnectInitialDelay: Duration(seconds: 1),
      locationUpdateInterval: Duration(seconds: 30),
      allowBackgroundScanning: true,
    );
  }

  /// Default balanced policy: 6s scan / 12s pause window.
  factory BatteryOptimizationPolicy.balanced() {
    return const BatteryOptimizationPolicy(
      mode: BatteryMode.balanced,
      scanDuration: Duration(seconds: 6),
      pauseDuration: Duration(seconds: 12),
      maxReconnectAttempts: 4,
      reconnectInitialDelay: Duration(seconds: 2),
      locationUpdateInterval: Duration(seconds: 45),
      allowBackgroundScanning: true,
    );
  }

  /// Default background low-power policy: 4s opportunistic scan / 60s pause window.
  factory BatteryOptimizationPolicy.lowPower() {
    return const BatteryOptimizationPolicy(
      mode: BatteryMode.lowPower,
      scanDuration: Duration(seconds: 4),
      pauseDuration: Duration(seconds: 60),
      maxReconnectAttempts: 3,
      reconnectInitialDelay: Duration(seconds: 4),
      locationUpdateInterval: Duration(minutes: 2),
      allowBackgroundScanning: true,
    );
  }

  /// Default conserve policy: 4s scan / 120s pause window.
  factory BatteryOptimizationPolicy.conserve() {
    return const BatteryOptimizationPolicy(
      mode: BatteryMode.conserve,
      scanDuration: Duration(seconds: 4),
      pauseDuration: Duration(seconds: 120),
      maxReconnectAttempts: 2,
      reconnectInitialDelay: Duration(seconds: 8),
      locationUpdateInterval: Duration(minutes: 5),
      allowBackgroundScanning: false,
    );
  }

  /// Duty cycle fraction (active radio scan time / total cycle time).
  double get dutyCycleRatio {
    final total = scanDuration.inMilliseconds + pauseDuration.inMilliseconds;
    if (total == 0) return 0.0;
    return scanDuration.inMilliseconds / total;
  }
}
