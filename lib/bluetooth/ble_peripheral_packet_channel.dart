import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

import 'offlink_ble_service.dart';

abstract interface class BlePeripheralPacketChannel {
  Stream<Uint8List> get incomingData;

  Future<void> sendData(Uint8List data);
}

class FlutterBlePeripheralPacketChannel implements BlePeripheralPacketChannel {
  FlutterBlePeripheralPacketChannel({FlutterBlePeripheral? peripheral})
    : _peripheral = peripheral ?? FlutterBlePeripheral();

  final FlutterBlePeripheral _peripheral;

  @override
  Stream<Uint8List> get incomingData => _peripheral.onDataReceived;

  @override
  Future<void> sendData(Uint8List data) {
    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'BLE data must not be empty.');
    }

    return _peripheral.sendData(
      data,
      characteristicUuid: OfflinkBleService.txCharacteristicUuid,
    );
  }
}
