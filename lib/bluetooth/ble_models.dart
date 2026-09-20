enum BleConnectionState { disconnected, connecting, connected, disconnecting }

class BlePeer {
  const BlePeer({
    required this.peerId,
    required this.displayName,
    this.signalStrength,
  });

  final String peerId;
  final String displayName;
  final int? signalStrength;
}

class BlePacket {
  const BlePacket({required this.peerId, required this.payload});

  final String peerId;
  final List<int> payload;
}
