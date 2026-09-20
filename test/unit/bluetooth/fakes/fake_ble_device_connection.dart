import 'package:offlink/bluetooth/ble_device_connection.dart';
import 'package:offlink/bluetooth/ble_models.dart';

class FakeBleDeviceConnection implements BleDeviceConnection {
  bool connectCalled = false;
  bool disconnectCalled = false;

  BlePeer? connectedPeer;
  BlePeer? disconnectedPeer;

  Object? connectError;
  Object? disconnectError;

  @override
  Future<void> connect(BlePeer peer) async {
    connectCalled = true;
    connectedPeer = peer;

    if (connectError != null) {
      throw connectError!;
    }
  }

  @override
  Future<void> disconnect(BlePeer peer) async {
    disconnectCalled = true;
    disconnectedPeer = peer;

    if (disconnectError != null) {
      throw disconnectError!;
    }
  }
}