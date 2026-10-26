import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

import 'offlink_ble_service.dart';

abstract interface class BleAdvertiser {
  Future<void> start();

  Future<void> stop();
}

class FlutterBleAdvertiser implements BleAdvertiser {
  const FlutterBleAdvertiser();

  @override
  Future<void> start() {
    return FlutterBlePeripheral().start(
      advertiseData: AdvertiseDataCore(
        serviceUuid: OfflinkBleService.serviceUuid,
      ),
      gattServer: GattServerSettings(
        serviceUuid: OfflinkBleService.serviceUuid,
        txCharacteristicUuid: OfflinkBleService.txCharacteristicUuid,
        rxCharacteristicUuid: OfflinkBleService.rxCharacteristicUuid,
      ),
    );
  }

  @override
  Future<void> stop() {
    return FlutterBlePeripheral().stop();
  }

  Stream<Uint8List> get incomingData {
    return FlutterBlePeripheral().onDataReceived;
  }

  Future<void> sendData(Uint8List data) {
    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'BLE data must not be empty.');
    }

    return FlutterBlePeripheral().sendData(
      data,
      characteristicUuid: OfflinkBleService.txCharacteristicUuid,
    );
  }
}
