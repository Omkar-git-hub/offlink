import 'dart:async';

import 'transport.dart';

class PhoneBleTransport implements Transport {
  PhoneBleTransport();

  final StreamController<List<int>> _incomingPacketsController =
      StreamController<List<int>>.broadcast();

  bool _isStarted = false;

  @override
  Future<void> start() async {
    if (_isStarted) {
      return;
    }

    _isStarted = true;
  }

  @override
  Future<void> stop() async {
    if (!_isStarted) {
      return;
    }

    _isStarted = false;
  }

  @override
  Future<void> connect(String peerId) async {
    _ensureStarted();

    // BLE connection implementation belongs to the BLE discovery
    // and connection PR.
    throw UnimplementedError(
      'BLE connection is not implemented in the foundation layer.',
    );
  }

  @override
  Future<void> disconnect(String peerId) async {
    _ensureStarted();

    // BLE disconnection implementation belongs to the BLE discovery
    // and connection PR.
    throw UnimplementedError(
      'BLE disconnection is not implemented in the foundation layer.',
    );
  }

  @override
  Future<void> send({required String peerId, required List<int> data}) async {
    _ensureStarted();

    // Packet transmission belongs to a later transport phase.
    throw UnimplementedError(
      'BLE packet transmission is not implemented in the foundation layer.',
    );
  }

  @override
  Stream<List<int>> get incomingPackets => _incomingPacketsController.stream;

  void _ensureStarted() {
    if (!_isStarted) {
      throw StateError('BLE transport has not been started.');
    }
  }

  Future<void> dispose() async {
    await _incomingPacketsController.close();
  }
}
