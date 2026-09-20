import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract interface class BleScanner {
  Stream<List<ScanResult>> get scanResults;

  Future<void> startScan({required List<Guid> withServices});

  Future<void> stopScan();
}

class FlutterBluePlusScanner implements BleScanner {
  const FlutterBluePlusScanner();

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Future<void> startScan({required List<Guid> withServices}) {
    return FlutterBluePlus.startScan(withServices: withServices);
  }

  @override
  Future<void> stopScan() {
    return FlutterBluePlus.stopScan();
  }
}
