import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/domain/security/safety_fingerprint_generator.dart';

void main() {
  const generator = SafetyFingerprintGenerator();

  group('SafetyFingerprintGenerator', () {
    const keyA =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const keyB =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    test(
      'generateNumericFingerprint produces 12 blocks of 5 digits (60 digits total)',
      () async {
        final fingerprint = await generator.generateNumericFingerprint(
          localPublicKeyHex: keyA,
          peerPublicKeyHex: keyB,
        );

        final blocks = fingerprint.split(' ');
        expect(blocks.length, equals(12));
        for (final block in blocks) {
          expect(block.length, equals(5));
          expect(int.tryParse(block), isNotNull);
        }
      },
    );

    test(
      'generateNumericFingerprint is order-invariant (symmetric for both parties)',
      () async {
        final fpA = await generator.generateNumericFingerprint(
          localPublicKeyHex: keyA,
          peerPublicKeyHex: keyB,
        );
        final fpB = await generator.generateNumericFingerprint(
          localPublicKeyHex: keyB,
          peerPublicKeyHex: keyA,
        );

        expect(fpA, equals(fpB));
      },
    );

    test(
      'generateNumericFingerprint is case-insensitive and trims whitespace',
      () async {
        final fpA = await generator.generateNumericFingerprint(
          localPublicKeyHex: '  ${keyA.toUpperCase()} ',
          peerPublicKeyHex: keyB.toLowerCase(),
        );
        final fpB = await generator.generateNumericFingerprint(
          localPublicKeyHex: keyA.toLowerCase(),
          peerPublicKeyHex: keyB.toUpperCase(),
        );

        expect(fpA, equals(fpB));
      },
    );

    test(
      'different keys produce completely distinct numeric fingerprints',
      () async {
        const keyC =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final fpAB = await generator.generateNumericFingerprint(
          localPublicKeyHex: keyA,
          peerPublicKeyHex: keyB,
        );
        final fpAC = await generator.generateNumericFingerprint(
          localPublicKeyHex: keyA,
          peerPublicKeyHex: keyC,
        );

        expect(fpAB, isNot(equals(fpAC)));
      },
    );

    test(
      'generateVisualFingerprint produces XXXX-XXXX-XXXX-XXXX format and is order-invariant',
      () async {
        final visualA = await generator.generateVisualFingerprint(
          localPublicKeyHex: keyA,
          peerPublicKeyHex: keyB,
        );
        final visualB = await generator.generateVisualFingerprint(
          localPublicKeyHex: keyB,
          peerPublicKeyHex: keyA,
        );

        expect(visualA, equals(visualB));
        expect(
          RegExp(
            r'^[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}$',
          ).hasMatch(visualA),
          isTrue,
        );
      },
    );
  });
}
