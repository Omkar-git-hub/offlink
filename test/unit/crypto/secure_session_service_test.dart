import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/crypto/session/encrypted_payload.dart';
import 'package:offlink/crypto/session/handshake_payload.dart';
import 'package:offlink/crypto/session/secure_session_service.dart';

import '../identity/fakes/fake_secure_key_storage.dart';

void main() {
  group('SecureSessionService', () {
    late IdentityKeyService aliceKeyService;
    late IdentityKeyService bobKeyService;
    late SecureSessionService aliceSessionService;
    late SecureSessionService bobSessionService;

    const aliceNodeId = 'node-alice-12345678';
    const bobNodeId = 'node-bob-87654321';

    setUp(() async {
      aliceKeyService = IdentityKeyService(
        secureStorage: FakeSecureKeyStorage(),
      );
      bobKeyService = IdentityKeyService(secureStorage: FakeSecureKeyStorage());

      final aliceKeyPair = await aliceKeyService.generateKeyPair();
      await aliceKeyService.storePrivateKey(aliceKeyPair.privateKey);

      final bobKeyPair = await bobKeyService.generateKeyPair();
      await bobKeyService.storePrivateKey(bobKeyPair.privateKey);

      aliceSessionService = SecureSessionService(
        identityKeyService: aliceKeyService,
        getLocalNodeId: () => aliceNodeId,
      );

      bobSessionService = SecureSessionService(
        identityKeyService: bobKeyService,
        getLocalNodeId: () => bobNodeId,
      );
    });

    test(
      'completes 2-way handshake and establishes matching sessions',
      () async {
        expect(aliceSessionService.hasSession(bobNodeId), isFalse);
        expect(bobSessionService.hasSession(aliceNodeId), isFalse);

        // 1. Alice creates handshake init
        final initPayload = await aliceSessionService.createHandshakeInit(
          bobNodeId,
        );
        expect(initPayload.senderNodeId, equals(aliceNodeId));
        expect(initPayload.signature, isNotEmpty);

        // 2. Bob handles handshake init and creates response
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );
        expect(responsePayload.senderNodeId, equals(bobNodeId));
        expect(responsePayload.recipientNodeId, equals(aliceNodeId));
        expect(
          responsePayload.peerEphemeralPublicKey,
          equals(initPayload.ephemeralPublicKey),
        );
        expect(bobSessionService.hasSession(aliceNodeId), isTrue);

        // 3. Alice handles handshake response
        final aliceSession = await aliceSessionService.handleHandshakeResponse(
          responsePayload,
        );
        expect(aliceSessionService.hasSession(bobNodeId), isTrue);

        final bobSession = bobSessionService.getSession(aliceNodeId)!;

        // Session fingerprints match
        expect(
          aliceSession.sessionFingerprint,
          equals(bobSession.sessionFingerprint),
        );

        // Derived session key bytes match
        final aliceKeyBytes = await aliceSession.sessionKey.extractBytes();
        final bobKeyBytes = await bobSession.sessionKey.extractBytes();
        expect(aliceKeyBytes, equals(bobKeyBytes));
      },
    );

    test('encrypts and decrypts messages with envelope AAD binding', () async {
      final initPayload = await aliceSessionService.createHandshakeInit(
        bobNodeId,
      );
      final responsePayload = await bobSessionService.handleHandshakeInit(
        initPayload,
      );
      await aliceSessionService.handleHandshakeResponse(responsePayload);

      const plaintext = 'Secret Offlink peer-to-peer message';
      const messageId = 'msg-1001';

      // Alice encrypts for Bob
      final encryptedPayload = await aliceSessionService.encrypt(
        peerNodeId: bobNodeId,
        plaintext: plaintext,
        messageId: messageId,
        senderNodeId: aliceNodeId,
        recipientNodeId: bobNodeId,
      );

      expect(encryptedPayload.sequenceNumber, equals(1));
      expect(encryptedPayload.ciphertext, isNotEmpty);
      expect(encryptedPayload.ciphertext, isNot(equals(plaintext)));

      // Bob decrypts from Alice
      final decrypted = await bobSessionService.decrypt(
        peerNodeId: aliceNodeId,
        encryptedPayload: encryptedPayload,
        messageId: messageId,
        senderNodeId: aliceNodeId,
        recipientNodeId: bobNodeId,
      );

      expect(decrypted, equals(plaintext));
    });

    test('rejects tampered ciphertext without leaking plaintext', () async {
      final initPayload = await aliceSessionService.createHandshakeInit(
        bobNodeId,
      );
      final responsePayload = await bobSessionService.handleHandshakeInit(
        initPayload,
      );
      await aliceSessionService.handleHandshakeResponse(responsePayload);

      const plaintext = 'Sensitive text that should not leak';
      const messageId = 'msg-1002';

      final encryptedPayload = await aliceSessionService.encrypt(
        peerNodeId: bobNodeId,
        plaintext: plaintext,
        messageId: messageId,
        senderNodeId: aliceNodeId,
        recipientNodeId: bobNodeId,
      );

      // Tamper ciphertext
      final rawCiphertext = base64Decode(encryptedPayload.ciphertext);
      rawCiphertext[0] ^= 0xFF;
      final tamperedPayload = EncryptedPayload(
        ciphertext: base64Encode(rawCiphertext),
        nonce: encryptedPayload.nonce,
        mac: encryptedPayload.mac,
        sequenceNumber: encryptedPayload.sequenceNumber,
        sessionFingerprint: encryptedPayload.sessionFingerprint,
      );

      expect(
        () => bobSessionService.decrypt(
          peerNodeId: aliceNodeId,
          encryptedPayload: tamperedPayload,
          messageId: messageId,
          senderNodeId: aliceNodeId,
          recipientNodeId: bobNodeId,
        ),
        throwsA(isA<DecryptionAuthenticationException>()),
      );
    });

    test(
      'rejects tampered AAD headers (messageId or recipient mismatch)',
      () async {
        final initPayload = await aliceSessionService.createHandshakeInit(
          bobNodeId,
        );
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );
        await aliceSessionService.handleHandshakeResponse(responsePayload);

        final encryptedPayload = await aliceSessionService.encrypt(
          peerNodeId: bobNodeId,
          plaintext: 'Hello Bob',
          messageId: 'msg-original',
          senderNodeId: aliceNodeId,
          recipientNodeId: bobNodeId,
        );

        // Wrong messageId in AAD
        expect(
          () => bobSessionService.decrypt(
            peerNodeId: aliceNodeId,
            encryptedPayload: encryptedPayload,
            messageId: 'msg-tampered',
            senderNodeId: aliceNodeId,
            recipientNodeId: bobNodeId,
          ),
          throwsA(isA<DecryptionAuthenticationException>()),
        );

        // Wrong recipientNodeId in AAD
        expect(
          () => bobSessionService.decrypt(
            peerNodeId: aliceNodeId,
            encryptedPayload: encryptedPayload,
            messageId: 'msg-original',
            senderNodeId: aliceNodeId,
            recipientNodeId: 'node-mallory',
          ),
          throwsA(isA<DecryptionAuthenticationException>()),
        );
      },
    );

    test(
      'rejects replay attacks with identical or earlier sequence numbers',
      () async {
        final initPayload = await aliceSessionService.createHandshakeInit(
          bobNodeId,
        );
        final responsePayload = await bobSessionService.handleHandshakeInit(
          initPayload,
        );
        await aliceSessionService.handleHandshakeResponse(responsePayload);

        final encrypted1 = await aliceSessionService.encrypt(
          peerNodeId: bobNodeId,
          plaintext: 'Message 1',
          messageId: 'msg-1',
          senderNodeId: aliceNodeId,
          recipientNodeId: bobNodeId,
        );

        // First decrypt succeeds
        final decrypted1 = await bobSessionService.decrypt(
          peerNodeId: aliceNodeId,
          encryptedPayload: encrypted1,
          messageId: 'msg-1',
          senderNodeId: aliceNodeId,
          recipientNodeId: bobNodeId,
        );
        expect(decrypted1, equals('Message 1'));

        // Replaying the exact same message throws ReplayAttackException
        expect(
          () => bobSessionService.decrypt(
            peerNodeId: aliceNodeId,
            encryptedPayload: encrypted1,
            messageId: 'msg-1',
            senderNodeId: aliceNodeId,
            recipientNodeId: bobNodeId,
          ),
          throwsA(isA<ReplayAttackException>()),
        );
      },
    );

    test('rejects forged handshake init signature', () async {
      final initPayload = await aliceSessionService.createHandshakeInit(
        bobNodeId,
      );

      // Tamper signature
      final rawSig = base64Decode(initPayload.signature);
      rawSig[0] ^= 0xFF;
      final tamperedInit = HandshakeInitPayload(
        senderNodeId: initPayload.senderNodeId,
        senderIdentityPublicKey: initPayload.senderIdentityPublicKey,
        ephemeralPublicKey: initPayload.ephemeralPublicKey,
        timestamp: initPayload.timestamp,
        signature: base64Encode(rawSig),
      );

      expect(
        () => bobSessionService.handleHandshakeInit(tamperedInit),
        throwsA(isA<HandshakeValidationException>()),
      );
    });

    test(
      'rejects handshake response when peer ephemeral key does not match',
      () async {
        await aliceSessionService.createHandshakeInit(bobNodeId);

        final bobKeyPair = (await bobKeyService.loadPrivateKey())!;
        final bobPubHex = (await bobKeyService.exportPublicKey(
          await bobKeyPair.extractPublicKey(),
        )).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        final unsignedResponse = HandshakeResponsePayload(
          senderNodeId: bobNodeId,
          recipientNodeId: aliceNodeId,
          senderIdentityPublicKey: bobPubHex,
          ephemeralPublicKey: 'fake-ephemeral',
          peerEphemeralPublicKey: 'unmatched-ephemeral',
          timestamp: DateTime.now().toUtc(),
          signature: '',
        );

        final sig = await Ed25519().sign(
          unsignedResponse.toSignableBytes(),
          keyPair: bobKeyPair,
        );

        final mismatchedResponse = HandshakeResponsePayload(
          senderNodeId: unsignedResponse.senderNodeId,
          recipientNodeId: unsignedResponse.recipientNodeId,
          senderIdentityPublicKey: unsignedResponse.senderIdentityPublicKey,
          ephemeralPublicKey: unsignedResponse.ephemeralPublicKey,
          peerEphemeralPublicKey: unsignedResponse.peerEphemeralPublicKey,
          timestamp: unsignedResponse.timestamp,
          signature: base64Encode(sig.bytes),
        );

        expect(
          () => aliceSessionService.handleHandshakeResponse(mismatchedResponse),
          throwsA(isA<HandshakeValidationException>()),
        );
      },
    );

    test(
      'throws SessionNotFoundException when operating without active session',
      () async {
        expect(
          () => aliceSessionService.encrypt(
            peerNodeId: 'unknown-peer',
            plaintext: 'Hello',
            messageId: 'msg-1',
            senderNodeId: aliceNodeId,
            recipientNodeId: 'unknown-peer',
          ),
          throwsA(isA<SessionNotFoundException>()),
        );

        final dummyBox = SecretBox([], nonce: [0], mac: Mac([]));
        final dummyPayload = EncryptedPayload.fromSecretBox(
          secretBox: dummyBox,
          sequenceNumber: 1,
          sessionFingerprint: 'fprint',
        );

        expect(
          () => aliceSessionService.decrypt(
            peerNodeId: 'unknown-peer',
            encryptedPayload: dummyPayload,
            messageId: 'msg-1',
            senderNodeId: 'unknown-peer',
            recipientNodeId: aliceNodeId,
          ),
          throwsA(isA<SessionNotFoundException>()),
        );
      },
    );
  });
}
