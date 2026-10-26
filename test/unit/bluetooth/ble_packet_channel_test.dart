import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_packet_channel.dart';

class StubBlePacketChannel implements BlePacketChannel {
  bool initialized = false;
  bool disposed = false;
  final List<Uint8List> sent = [];

  @override
  Stream<Uint8List> get incomingPackets => const Stream.empty();

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<void> sendBytes(Uint8List data) async {
    sent.add(data);
  }

  @override
  Future<void> sendText(String value) async {
    await sendBytes(Uint8List.fromList(value.codeUnits));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('BlePacketChannel', () {
    test('abstract interface contract is implementable', () async {
      final channel = StubBlePacketChannel();
      expect(channel.initialized, isFalse);

      await channel.initialize();
      expect(channel.initialized, isTrue);

      await channel.sendText('hello');
      expect(channel.sent, hasLength(1));

      await channel.dispose();
      expect(channel.disposed, isTrue);
    });
  });
}
