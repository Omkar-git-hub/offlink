enum BleConnectionState { disconnected, connecting, connected, disconnecting }

class BlePeer {
  const BlePeer({
    required this.peerId,
    required this.displayName,
    this.deviceModel,
    this.username,
    this.signalStrength,
  });

  /// Remote BLE device identifier (e.g. MAC address on Android or UUID on iOS).
  final String peerId;

  /// User-facing display name. Prefers configured Offlink username or fallback 'Offlink User'.
  final String displayName;

  /// Hardware platform / device manufacturer model (e.g. 'Motorola Edge 50 Pro', 'Pixel 8').
  final String? deviceModel;

  /// Configured Offlink username if verified through scan response or session handshake.
  final String? username;

  /// Received Signal Strength Indication (RSSI) in dBm.
  final int? signalStrength;

  BlePeer copyWith({
    String? peerId,
    String? displayName,
    String? deviceModel,
    String? username,
    int? signalStrength,
  }) {
    return BlePeer(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      deviceModel: deviceModel ?? this.deviceModel,
      username: username ?? this.username,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlePeer &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId &&
          displayName == other.displayName &&
          deviceModel == other.deviceModel &&
          username == other.username &&
          signalStrength == other.signalStrength;

  @override
  int get hashCode =>
      Object.hash(peerId, displayName, deviceModel, username, signalStrength);

  @override
  String toString() =>
      'BlePeer(peerId: $peerId, displayName: $displayName, deviceModel: $deviceModel, username: $username, signalStrength: $signalStrength)';
}

class BlePacket {
  const BlePacket({required this.peerId, required this.payload});

  final String peerId;
  final List<int> payload;
}
