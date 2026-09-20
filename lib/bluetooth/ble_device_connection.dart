import 'ble_models.dart';

abstract interface class BleDeviceConnection {
  Future<void> connect(BlePeer peer);

  Future<void> disconnect(BlePeer peer);
}