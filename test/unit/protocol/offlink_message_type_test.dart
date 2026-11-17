import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';

void main() {
  group('OfflinkMessageTypeCodec', () {
    test('encodes and decodes all message types', () {
      final expectations = {
        OfflinkMessageType.text: 'text',
        OfflinkMessageType.acknowledgement: 'ack',
        OfflinkMessageType.encrypted: 'enc',
        OfflinkMessageType.handshakeInit: 'handshake_init',
        OfflinkMessageType.handshakeResponse: 'handshake_resp',
      };

      for (final entry in expectations.entries) {
        expect(entry.key.value, equals(entry.value));
        expect(
          OfflinkMessageTypeCodec.fromValue(entry.value),
          equals(entry.key),
        );
      }
    });

    test('throws FormatException on unsupported message type string', () {
      expect(
        () => OfflinkMessageTypeCodec.fromValue('invalid_type'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
