import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.sequenceNumber,
    required this.sessionFingerprint,
  });

  final String ciphertext;
  final String nonce;
  final String mac;
  final int sequenceNumber;
  final String sessionFingerprint;

  factory EncryptedPayload.fromSecretBox({
    required SecretBox secretBox,
    required int sequenceNumber,
    required String sessionFingerprint,
  }) {
    return EncryptedPayload(
      ciphertext: base64Encode(secretBox.cipherText),
      nonce: base64Encode(secretBox.nonce),
      mac: base64Encode(secretBox.mac.bytes),
      sequenceNumber: sequenceNumber,
      sessionFingerprint: sessionFingerprint,
    );
  }

  SecretBox toSecretBox() {
    return SecretBox(
      base64Decode(ciphertext),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ciphertext': ciphertext,
      'nonce': nonce,
      'mac': mac,
      'sequenceNumber': sequenceNumber,
      'sessionFingerprint': sessionFingerprint,
    };
  }

  String encode() {
    return jsonEncode(toMap());
  }

  factory EncryptedPayload.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('ciphertext') ||
        !map.containsKey('nonce') ||
        !map.containsKey('mac') ||
        !map.containsKey('sequenceNumber') ||
        !map.containsKey('sessionFingerprint')) {
      throw const FormatException(
        'Missing required fields for EncryptedPayload.',
      );
    }

    return EncryptedPayload(
      ciphertext: map['ciphertext'] as String,
      nonce: map['nonce'] as String,
      mac: map['mac'] as String,
      sequenceNumber: map['sequenceNumber'] as int,
      sessionFingerprint: map['sessionFingerprint'] as String,
    );
  }

  factory EncryptedPayload.decode(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('EncryptedPayload must be a JSON object.');
    }
    return EncryptedPayload.fromMap(decoded);
  }
}
