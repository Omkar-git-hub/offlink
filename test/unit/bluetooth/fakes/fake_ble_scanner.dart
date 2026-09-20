import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:offlink/bluetooth/ble_scanner.dart';

class FakeBleScanner implements BleScanner {
  final StreamController<List<ScanResult>> _resultsController =
      StreamController<List<ScanResult>>.broadcast();

  bool startCalled = false;
  bool stopCalled = false;

  List<Guid> startedWithServices = [];

  @override
  Stream<List<ScanResult>> get scanResults => _resultsController.stream;

  @override
  Future<void> startScan({required List<Guid> withServices}) async {
    startCalled = true;
    startedWithServices = List<Guid>.from(withServices);
  }

  @override
  Future<void> stopScan() async {
    stopCalled = true;
  }

  void emitResults(List<ScanResult> results) {
    _resultsController.add(results);
  }

  Future<void> dispose() async {
    await _resultsController.close();
  }
}
