import 'package:offlink/bluetooth/ble_advertiser.dart';

class FakeBleAdvertiser implements BleAdvertiser {
  bool startCalled = false;
  bool stopCalled = false;

  @override
  Future<void> start() async {
    startCalled = true;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }
}
