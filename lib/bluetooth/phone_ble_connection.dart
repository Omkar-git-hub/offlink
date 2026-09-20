import 'dart:async';

import 'ble_device_connection.dart';
import 'ble_models.dart';
import 'connection.dart';

class PhoneBleConnection implements BleConnection {
  PhoneBleConnection({required this.deviceConnection});

  final BleDeviceConnection deviceConnection;

  final StreamController<BleConnectionState> _connectionStateController =
      StreamController<BleConnectionState>.broadcast();

  final Map<String, BlePeer> _connectedPeers = {};

  @override
  Future<void> connect(BlePeer peer) async {
    _connectionStateController.add(BleConnectionState.connecting);

    try {
      await deviceConnection.connect(peer);

      _connectedPeers[peer.peerId] = peer;

      _connectionStateController.add(BleConnectionState.connected);
    } catch (_) {
      _connectionStateController.add(BleConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String peerId) async {
    final peer = _connectedPeers[peerId];

    if (peer == null) {
      return;
    }

    _connectionStateController.add(BleConnectionState.disconnecting);

    try {
      await deviceConnection.disconnect(peer);
    } finally {
      _connectedPeers.remove(peerId);

      _connectionStateController.add(BleConnectionState.disconnected);
    }
  }

  @override
  Stream<BleConnectionState> get connectionStates =>
      _connectionStateController.stream;

  Future<void> dispose() async {
    for (final peer in _connectedPeers.values.toList()) {
      await deviceConnection.disconnect(peer);
    }

    _connectedPeers.clear();

    await _connectionStateController.close();
  }
}
