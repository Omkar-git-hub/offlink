class BleScanData {
  const BleScanData({
    required this.peerId,
    required this.displayName,
    required this.signalStrength,
    required this.serviceUuids,
  });

  final String peerId;
  final String displayName;
  final int signalStrength;
  final List<String> serviceUuids;
}
