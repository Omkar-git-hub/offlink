import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_device_connection.dart';
import 'package:offlink/bluetooth/flutter_blue_plus_device_connection.dart';

void main() {
  test('FlutterBluePlusDeviceConnection implements BleDeviceConnection', () {
    const BleDeviceConnection connection = FlutterBluePlusDeviceConnection();

    expect(connection, isA<BleDeviceConnection>());
  });
}
