import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cryptography primitives verification', () async {
    // 1. Ed25519 Sign and Verify
    final ed25519 = Ed25519();
    final identityA = await ed25519.newKeyPair();
    final pubA = await identityA.extractPublicKey();
    expect(pubA.bytes, isNotEmpty);

    final messageToSign = utf8.encode('handshake-data-123');
    final signature = await ed25519.sign(messageToSign, keyPair: identityA);
    final isValid = await ed25519.verify(messageToSign, signature: signature);
    expect(isValid, isTrue);

    // Negative check: altered message
    final isAlteredValid = await ed25519.verify(
      utf8.encode('altered-data'),
      signature: signature,
    );
    expect(isAlteredValid, isFalse);

    // 2. X25519 Key Agreement
    final x25519 = X25519();
    final ephemeralA = await x25519.newKeyPair();
    final ephemeralB = await x25519.newKeyPair();

    final pubEphemeralA = await ephemeralA.extractPublicKey();
    final pubEphemeralB = await ephemeralB.extractPublicKey();

    final sharedA = await x25519.sharedSecretKey(
      keyPair: ephemeralA,
      remotePublicKey: pubEphemeralB,
    );
    final sharedB = await x25519.sharedSecretKey(
      keyPair: ephemeralB,
      remotePublicKey: pubEphemeralA,
    );

    final sharedBytesA = await sharedA.extractBytes();
    final sharedBytesB = await sharedB.extractBytes();
    expect(sharedBytesA, equals(sharedBytesB));

    // 3. HKDF Key Derivation
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final sessionKeyA = await hkdf.deriveKey(
      secretKey: sharedA,
      nonce: utf8.encode('offlink-salt'),
      info: utf8.encode('offlink-v1-session'),
    );
    final sessionKeyB = await hkdf.deriveKey(
      secretKey: sharedB,
      nonce: utf8.encode('offlink-salt'),
      info: utf8.encode('offlink-v1-session'),
    );
    expect(
      await sessionKeyA.extractBytes(),
      equals(await sessionKeyB.extractBytes()),
    );

    // 4. AES-256-GCM AEAD Encryption and Decryption
    final aesGcm = AesGcm.with256bits();
    final plaintext = utf8.encode('Secret Offlink Message');
    final aad = utf8.encode('msg-1:node-a:node-b:1');

    final secretBox = await aesGcm.encrypt(
      plaintext,
      secretKey: sessionKeyA,
      aad: aad,
    );

    final decrypted = await aesGcm.decrypt(
      secretBox,
      secretKey: sessionKeyB,
      aad: aad,
    );
    expect(utf8.decode(decrypted), 'Secret Offlink Message');

    // Negative check: wrong AAD fails authentication
    expect(
      () => aesGcm.decrypt(
        secretBox,
        secretKey: sessionKeyB,
        aad: utf8.encode('tampered-aad'),
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
