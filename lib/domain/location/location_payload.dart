import 'dart:convert';

/// Type of location sharing being communicated.
enum LocationSharingType {
  /// A one-time location snapshot.
  oneTime,

  /// An active periodic live location update.
  liveUpdate,

  /// Notification that live location sharing has concluded.
  liveStop,
}

extension LocationSharingTypeCodec on LocationSharingType {
  String get value {
    switch (this) {
      case LocationSharingType.oneTime:
        return 'one_time';
      case LocationSharingType.liveUpdate:
        return 'live_update';
      case LocationSharingType.liveStop:
        return 'live_stop';
    }
  }

  static LocationSharingType fromValue(String value) {
    switch (value) {
      case 'one_time':
        return LocationSharingType.oneTime;
      case 'live_update':
        return LocationSharingType.liveUpdate;
      case 'live_stop':
        return LocationSharingType.liveStop;
      default:
        throw FormatException('Unsupported LocationSharingType: $value');
    }
  }
}

/// Wire and persistence payload structure for Offlink location messages.
class LocationPayload {
  const LocationPayload({
    required this.locationId,
    required this.senderNodeId,
    required this.senderDisplayName,
    this.recipientNodeId,
    this.groupId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    this.expiresAt,
    this.sharingType = LocationSharingType.oneTime,
    this.liveSessionId,
    this.isLive = false,
  });

  /// Canonical ID for this location packet or update.
  final String locationId;

  /// Node ID of the sending peer.
  final String senderNodeId;

  /// Display name of the sending peer.
  final String senderDisplayName;

  /// Recipient node ID if sent directly 1-to-1.
  final String? recipientNodeId;

  /// Group ID if shared with a group.
  final String? groupId;

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Accuracy radius in meters, if known.
  final double? accuracy;

  /// Timestamp when the position was captured (UTC).
  final DateTime timestamp;

  /// Optional expiration timestamp (UTC).
  final DateTime? expiresAt;

  /// Type of sharing: oneTime, liveUpdate, or liveStop.
  final LocationSharingType sharingType;

  /// Unique session ID if this update belongs to an ongoing live session.
  final String? liveSessionId;

  /// True if live location sharing is currently active for this sender.
  final bool isLive;

  /// Checks whether this payload is expired based on [now] (UTC).
  bool isExpired([DateTime? now]) {
    if (expiresAt == null) return false;
    final current = (now ?? DateTime.now()).toUtc();
    return current.isAfter(expiresAt!);
  }

  Map<String, dynamic> toMap() {
    return {
      '_type': 'location',
      'locationId': locationId,
      'senderNodeId': senderNodeId,
      'senderDisplayName': senderDisplayName,
      if (recipientNodeId != null) 'recipientNodeId': recipientNodeId,
      if (groupId != null) 'groupId': groupId,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
      'sharingType': sharingType.value,
      if (liveSessionId != null) 'liveSessionId': liveSessionId,
      'isLive': isLive,
    };
  }

  String encode() => jsonEncode(toMap());

  factory LocationPayload.fromMap(Map<String, dynamic> map) {
    if (map['latitude'] == null || map['longitude'] == null) {
      throw const FormatException('Location payload missing coordinates.');
    }

    final lat = (map['latitude'] as num).toDouble();
    final lon = (map['longitude'] as num).toDouble();

    if (lat < -90.0 || lat > 90.0) {
      throw FormatException('Latitude out of range: $lat');
    }
    if (lon < -180.0 || lon > 180.0) {
      throw FormatException('Longitude out of range: $lon');
    }

    return LocationPayload(
      locationId: map['locationId'] as String? ?? '',
      senderNodeId: map['senderNodeId'] as String? ?? '',
      senderDisplayName: map['senderDisplayName'] as String? ?? 'Peer',
      recipientNodeId: map['recipientNodeId'] as String?,
      groupId: map['groupId'] as String?,
      latitude: lat,
      longitude: lon,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String).toUtc(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String).toUtc()
          : null,
      sharingType: map['sharingType'] != null
          ? LocationSharingTypeCodec.fromValue(map['sharingType'] as String)
          : LocationSharingType.oneTime,
      liveSessionId: map['liveSessionId'] as String?,
      isLive: map['isLive'] as bool? ?? false,
    );
  }

  factory LocationPayload.decode(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Location payload must be a JSON object.');
    }
    return LocationPayload.fromMap(decoded);
  }

  /// Determines whether a raw string content represents a serialized LocationPayload.
  static bool isLocationMessage(String content) {
    try {
      if (!content.startsWith('{') || !content.contains('"_type":"location"')) {
        // Also check with spaces
        if (!content.contains('"_type": "location"')) {
          return false;
        }
      }
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> && decoded['_type'] == 'location';
    } catch (_) {
      return false;
    }
  }

  LocationPayload copyWith({
    String? locationId,
    String? senderNodeId,
    String? senderDisplayName,
    String? recipientNodeId,
    String? groupId,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    DateTime? expiresAt,
    LocationSharingType? sharingType,
    String? liveSessionId,
    bool? isLive,
  }) {
    return LocationPayload(
      locationId: locationId ?? this.locationId,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      recipientNodeId: recipientNodeId ?? this.recipientNodeId,
      groupId: groupId ?? this.groupId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      expiresAt: expiresAt ?? this.expiresAt,
      sharingType: sharingType ?? this.sharingType,
      liveSessionId: liveSessionId ?? this.liveSessionId,
      isLive: isLive ?? this.isLive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPayload &&
          runtimeType == other.runtimeType &&
          locationId == other.locationId &&
          senderNodeId == other.senderNodeId &&
          senderDisplayName == other.senderDisplayName &&
          recipientNodeId == other.recipientNodeId &&
          groupId == other.groupId &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracy == other.accuracy &&
          timestamp == other.timestamp &&
          expiresAt == other.expiresAt &&
          sharingType == other.sharingType &&
          liveSessionId == other.liveSessionId &&
          isLive == other.isLive;

  @override
  int get hashCode =>
      locationId.hashCode ^
      senderNodeId.hashCode ^
      senderDisplayName.hashCode ^
      recipientNodeId.hashCode ^
      groupId.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      accuracy.hashCode ^
      timestamp.hashCode ^
      expiresAt.hashCode ^
      sharingType.hashCode ^
      liveSessionId.hashCode ^
      isLive.hashCode;
}
