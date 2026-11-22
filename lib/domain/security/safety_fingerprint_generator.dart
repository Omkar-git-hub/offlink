import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class SafetyFingerprintGenerator {
  const SafetyFingerprintGenerator();

  /// Computes a deterministic 60-digit safety number (12 blocks of 5 digits)
  /// from the two parties' identity public keys.
  ///
  /// The public keys are lexicographically sorted so that both endpoints
  /// produce identical safety numbers regardless of role (initiator vs receiver).
  Future<String> generateNumericFingerprint({
    required String localPublicKeyHex,
    required String peerPublicKeyHex,
  }) async {
    final sorted = [
      localPublicKeyHex.trim().toLowerCase(),
      peerPublicKeyHex.trim().toLowerCase(),
    ]..sort();

    final transcript = utf8.encode(
      'offlink-safety-v1:${sorted[0]}:${sorted[1]}',
    );
    final hash = await Sha256().hash(transcript);
    final bytes = hash.bytes; // 32 bytes

    // Generate 12 chunks of 5 decimal digits each (60 digits total)
    // Using 24 bytes (12 pairs of bytes, modulo 100000, padded to 5 digits)
    final chunks = <String>[];
    for (var i = 0; i < 12; i++) {
      final b1 = bytes[i * 2];
      final b2 = bytes[i * 2 + 1];
      final val = ((b1 << 8) | b2) % 100000;
      chunks.add(val.toString().padLeft(5, '0'));
    }

    return chunks.join(' ');
  }

  /// Computes a short visual hex fingerprint (16 uppercase hex chars chunked in 4s: XXXX-XXXX-XXXX-XXXX).
  Future<String> generateVisualFingerprint({
    required String localPublicKeyHex,
    required String peerPublicKeyHex,
  }) async {
    final sorted = [
      localPublicKeyHex.trim().toLowerCase(),
      peerPublicKeyHex.trim().toLowerCase(),
    ]..sort();

    final transcript = utf8.encode(
      'offlink-safety-v1:${sorted[0]}:${sorted[1]}',
    );
    final hash = await Sha256().hash(transcript);
    final hexStr = hash.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();

    return '${hexStr.substring(0, 4)}-${hexStr.substring(4, 8)}-${hexStr.substring(8, 12)}-${hexStr.substring(12, 16)}';
  }
}
