import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';

import 'fakes/fake_secure_key_storage.dart';

void main() {
  group('IdentityKeyService', () {
    late FakeSecureKeyStorage storage;
    late IdentityKeyService service;

    setUp(() {
      storage = FakeSecureKeyStorage();

      service = IdentityKeyService(secureStorage: storage);
    });

    test('generates an Ed25519 key pair', () async {
      final keyPair = await service.generateKeyPair();

      expect(keyPair.publicKey.type, KeyPairType.ed25519);

      expect(keyPair.publicKey.bytes, isNotEmpty);
    });

    test('exports public key bytes', () async {
      final keyPair = await service.generateKeyPair();

      final exported = await service.exportPublicKey(keyPair.publicKey);

      expect(exported, equals(keyPair.publicKey.bytes));

      expect(exported, isNotEmpty);
    });

    test('exports private key bytes', () async {
      final keyPair = await service.generateKeyPair();

      final exported = await service.exportPrivateKey(keyPair.privateKey);

      expect(exported, isNotEmpty);
    });

    test('stores private key in secure storage', () async {
      final keyPair = await service.generateKeyPair();

      await service.storePrivateKey(keyPair.privateKey);

      expect(await service.hasPrivateKey(), isTrue);

      expect(await service.loadPrivateKeyBytes(), isNotNull);
    });

    test('loads the same private key bytes that were stored', () async {
      final keyPair = await service.generateKeyPair();

      final originalPrivateKey = await service.exportPrivateKey(
        keyPair.privateKey,
      );

      await service.storePrivateKey(keyPair.privateKey);

      final loadedPrivateKey = await service.loadPrivateKeyBytes();

      expect(loadedPrivateKey, equals(originalPrivateKey));
    });

    test(
      'restores the same Ed25519 key pair from stored private key',
      () async {
        final keyPair = await service.generateKeyPair();

        final originalPublicKey = await service.exportPublicKey(
          keyPair.publicKey,
        );

        await service.storePrivateKey(keyPair.privateKey);

        final restoredKeyPair = await service.loadPrivateKey();

        expect(restoredKeyPair, isNotNull);

        final restoredPublicKey = await restoredKeyPair!.extractPublicKey();

        expect(restoredPublicKey.bytes, equals(originalPublicKey));
      },
    );

    test('returns null when no private key exists', () async {
      final loadedKeyPair = await service.loadPrivateKey();

      expect(loadedKeyPair, isNull);
    });

    test('returns null public key when no private key exists', () async {
      final publicKey = await service.loadPrivateKeyPublicKey();

      expect(publicKey, isNull);
    });

    test('loads the public key from the restored private key', () async {
      final keyPair = await service.generateKeyPair();

      await service.storePrivateKey(keyPair.privateKey);

      final loadedPublicKey = await service.loadPrivateKeyPublicKey();

      expect(loadedPublicKey, isNotNull);

      expect(loadedPublicKey!.bytes, equals(keyPair.publicKey.bytes));
    });

    test('deletes the stored private key', () async {
      final keyPair = await service.generateKeyPair();

      await service.storePrivateKey(keyPair.privateKey);

      expect(await service.hasPrivateKey(), isTrue);

      await service.deletePrivateKey();

      expect(await service.hasPrivateKey(), isFalse);

      expect(await service.loadPrivateKey(), isNull);
    });
  });
}
