import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/session/encrypted_payload.dart';

void main() {
  group('EncryptedPayload', () {
    test('serializes and deserializes correctly', () {
      final secretBox = SecretBox(
        utf8.encode('ciphertext-bytes'),
        nonce: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        mac: Mac([10, 20, 30, 40, 50, 60, 70, 80]),
      );

      final payload = EncryptedPayload.fromSecretBox(
        secretBox: secretBox,
        sequenceNumber: 42,
        sessionFingerprint: 'abc123def456',
      );

      final encoded = payload.encode();
      final decoded = EncryptedPayload.decode(encoded);

      expect(decoded.ciphertext, equals(payload.ciphertext));
      expect(decoded.nonce, equals(payload.nonce));
      expect(decoded.mac, equals(payload.mac));
      expect(decoded.sequenceNumber, equals(42));
      expect(decoded.sessionFingerprint, equals('abc123def456'));

      final restoredSecretBox = decoded.toSecretBox();
      expect(restoredSecretBox.cipherText, equals(secretBox.cipherText));
      expect(restoredSecretBox.nonce, equals(secretBox.nonce));
      expect(restoredSecretBox.mac.bytes, equals(secretBox.mac.bytes));
    });

    test('throws FormatException on invalid json or missing fields', () {
      expect(
        () => EncryptedPayload.decode('not-a-json'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => EncryptedPayload.decode('{"ciphertext": "abc"}'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => EncryptedPayload.decode('["array", "not", "object"]'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
