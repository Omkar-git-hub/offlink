import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/phone_ble_transport.dart';

void main() {
  group('PhoneBleTransport', () {
    test('starts successfully', () async {
      final transport = PhoneBleTransport();

      await expectLater(transport.start(), completes);

      await transport.dispose();
    });

    test('start is idempotent', () async {
      final transport = PhoneBleTransport();

      await transport.start();
      await transport.start();

      await transport.dispose();
    });

    test('stop is safe before start', () async {
      final transport = PhoneBleTransport();

      await expectLater(transport.stop(), completes);

      await transport.dispose();
    });

    test('stop is idempotent', () async {
      final transport = PhoneBleTransport();

      await transport.start();
      await transport.stop();
      await transport.stop();

      await transport.dispose();
    });

    test('connect requires the transport to be started', () async {
      final transport = PhoneBleTransport();

      await expectLater(
        transport.connect('peer-123'),
        throwsA(isA<StateError>()),
      );

      await transport.dispose();
    });

    test('disconnect requires the transport to be started', () async {
      final transport = PhoneBleTransport();

      await expectLater(
        transport.disconnect('peer-123'),
        throwsA(isA<StateError>()),
      );

      await transport.dispose();
    });

    test('send requires the transport to be started', () async {
      final transport = PhoneBleTransport();

      await expectLater(
        transport.send(peerId: 'peer-123', data: [1, 2, 3]),
        throwsA(isA<StateError>()),
      );

      await transport.dispose();
    });

    test('incoming packet stream is available', () async {
      final transport = PhoneBleTransport();

      expect(transport.incomingPackets, isA<Stream<List<int>>>());

      await transport.dispose();
    });
  });
}
