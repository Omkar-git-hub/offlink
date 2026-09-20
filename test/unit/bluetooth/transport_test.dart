import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/transport.dart';

class TestTransport implements Transport {
  bool started = false;
  bool stopped = false;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> connect(String peerId) async {}

  @override
  Future<void> disconnect(String peerId) async {}

  @override
  Future<void> send({required String peerId, required List<int> data}) async {}

  @override
  Stream<List<int>> get incomingPackets => const Stream<List<int>>.empty();
}

void main() {
  group('Transport', () {
    test('can start and stop', () async {
      final transport = TestTransport();

      await transport.start();

      expect(transport.started, isTrue);
      expect(transport.stopped, isFalse);

      await transport.stop();

      expect(transport.stopped, isTrue);
    });

    test('exposes incoming packet stream', () {
      final transport = TestTransport();

      expect(transport.incomingPackets, isA<Stream<List<int>>>());
    });
  });
}
