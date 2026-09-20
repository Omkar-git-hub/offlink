import 'ble_models.dart';

abstract interface class BleConnection {
  Future<void> connect(BlePeer peer);

  Future<void> disconnect(String peerId);

  Stream<BleConnectionState> get connectionStates;
}
