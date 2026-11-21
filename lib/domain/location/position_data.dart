/// Geographic position domain entity for Offlink location sharing.
///
/// Decouples domain and presentation layers from third-party GPS plugins.
class PositionData {
  const PositionData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy = 0.0,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
  });

  /// Latitude in degrees, between -90.0 and +90.0.
  final double latitude;

  /// Longitude in degrees, between -180.0 and +180.0.
  final double longitude;

  /// Estimated horizontal accuracy of this position in meters.
  final double accuracy;

  /// Altitude of the device in meters above the WGS 84 reference ellipsoid.
  final double altitude;

  /// Instantaneous speed of the device in meters per second.
  final double speed;

  /// Direction of travel in degrees (0.0 to 360.0, clockwise from True North).
  final double heading;

  /// Time at which this position reading was captured (UTC).
  final DateTime timestamp;

  PositionData copyWith({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
  }) {
    return PositionData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionData &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracy == other.accuracy &&
          altitude == other.altitude &&
          speed == other.speed &&
          heading == other.heading &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      accuracy.hashCode ^
      altitude.hashCode ^
      speed.hashCode ^
      heading.hashCode ^
      timestamp.hashCode;

  @override
  String toString() =>
      'PositionData(lat: $latitude, lon: $longitude, acc: ${accuracy}m, time: $timestamp)';
}
