import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'offlink_ble_service.dart';

abstract interface class BlePacketChannel {
  factory BlePacketChannel(BluetoothDevice device) =
      FlutterBluePlusPacketChannel;

  Stream<Uint8List> get incomingPackets;

  Future<void> initialize();

  Future<void> sendBytes(Uint8List data);

  Future<void> sendText(String value);

  Future<void> dispose();
}

class FlutterBluePlusPacketChannel implements BlePacketChannel {
  FlutterBluePlusPacketChannel(this._device);

  final BluetoothDevice _device;

  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;

  StreamSubscription<List<int>>? _notificationSubscription;

  final StreamController<Uint8List> _incomingPackets =
      StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get incomingPackets => _incomingPackets.stream;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await _device.requestMtu(512);
    } catch (_) {
      // Ignore if MTU negotiation is not supported on this device/platform.
    }

    final services = await _device.discoverServices();

    BluetoothService? offlinkService;

    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          OfflinkBleService.serviceUuid.toLowerCase()) {
        offlinkService = service;
        break;
      }
    }

    if (offlinkService == null) {
      throw StateError('Offlink BLE service was not found.');
    }

    for (final characteristic in offlinkService.characteristics) {
      final uuid = characteristic.uuid.toString().toLowerCase();

      if (uuid == OfflinkBleService.txCharacteristicUuid.toLowerCase()) {
        _txCharacteristic = characteristic;
      }

      if (uuid == OfflinkBleService.rxCharacteristicUuid.toLowerCase()) {
        _rxCharacteristic = characteristic;
      }
    }

    if (_txCharacteristic == null) {
      throw StateError('Offlink TX characteristic was not found.');
    }

    if (_rxCharacteristic == null) {
      throw StateError('Offlink RX characteristic was not found.');
    }

    await _txCharacteristic!.setNotifyValue(true);

    _notificationSubscription = _txCharacteristic!.onValueReceived.listen((
      value,
    ) {
      if (value.isEmpty) {
        return;
      }

      _incomingPackets.add(Uint8List.fromList(value));
    });

    _initialized = true;
  }

  @override
  Future<void> sendBytes(Uint8List data) async {
    if (!_initialized || _rxCharacteristic == null) {
      throw StateError('BLE packet channel has not been initialized.');
    }

    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'Packet data must not be empty.');
    }

    await _rxCharacteristic!.write(data, withoutResponse: false);
  }

  @override
  Future<void> sendText(String value) async {
    await sendBytes(Uint8List.fromList(utf8.encode(value)));
  }

  @override
  Future<void> dispose() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    if (!_incomingPackets.isClosed) {
      await _incomingPackets.close();
    }

    _txCharacteristic = null;
    _rxCharacteristic = null;
    _initialized = false;
  }
}
