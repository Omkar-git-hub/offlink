import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_device_connection.dart';
import 'ble_models.dart';

class FlutterBluePlusDeviceConnection implements BleDeviceConnection {
  const FlutterBluePlusDeviceConnection();

  @override
  Future<void> connect(BlePeer peer) async {
    final device = BluetoothDevice.fromId(peer.peerId);

    await device.connect(license: License.nonprofit);
  }

  @override
  Future<void> disconnect(BlePeer peer) async {
    final device = BluetoothDevice.fromId(peer.peerId);

    await device.disconnect();
  }
}
