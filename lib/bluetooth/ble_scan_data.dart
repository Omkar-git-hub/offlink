class BleScanData {
  const BleScanData({
    required this.peerId,
    required this.displayName,
    this.deviceModel,
    this.username,
    required this.signalStrength,
    required this.serviceUuids,
  });

  final String peerId;
  final String displayName;
  final String? deviceModel;
  final String? username;
  final int signalStrength;
  final List<String> serviceUuids;
}
