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
    );
  }

  @override
  Future<void> stop() {
    return FlutterBlePeripheral().stop();
  }
}
