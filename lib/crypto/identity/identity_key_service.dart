import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'flutter_secure_key_storage.dart';
import 'secure_key_storage.dart';

class IdentityKeyPair {
  const IdentityKeyPair({required this.publicKey, required this.privateKey});

  final SimplePublicKey publicKey;
  final SimpleKeyPair privateKey;
}

class IdentityKeyService {
  IdentityKeyService({Ed25519? algorithm, SecureKeyStorage? secureStorage})
    : _algorithm = algorithm ?? Ed25519(),
      _secureStorage = secureStorage ?? FlutterSecureKeyStorage();

  static const _privateKeyStorageKey = 'offlink_identity_private_key';

  final Ed25519 _algorithm;
  final SecureKeyStorage _secureStorage;

  Future<IdentityKeyPair> generateKeyPair() async {
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    return IdentityKeyPair(publicKey: publicKey, privateKey: keyPair);
  }

  Future<List<int>> exportPublicKey(SimplePublicKey publicKey) async {
    return publicKey.bytes;
  }

  Future<List<int>> exportPrivateKey(SimpleKeyPair privateKey) {
    return privateKey.extractPrivateKeyBytes();
  }

  Future<void> storePrivateKey(SimpleKeyPair privateKey) async {
    final bytes = await privateKey.extractPrivateKeyBytes();

    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: base64Encode(bytes),
    );
  }

  Future<List<int>?> loadPrivateKeyBytes() async {
    final encoded = await _secureStorage.read(key: _privateKeyStorageKey);

    if (encoded == null) {
      return null;
    }

    return base64Decode(encoded);
  }

  Future<SimpleKeyPair?> loadPrivateKey() async {
    final seed = await loadPrivateKeyBytes();

    if (seed == null) {
      return null;
    }

    return _algorithm.newKeyPairFromSeed(seed);
  }

  Future<SimplePublicKey?> loadPrivateKeyPublicKey() async {
    final keyPair = await loadPrivateKey();

    if (keyPair == null) {
      return null;
    }

    return keyPair.extractPublicKey();
  }

  Future<bool> hasPrivateKey() {
    return _secureStorage.containsKey(key: _privateKeyStorageKey);
  }

  Future<void> deletePrivateKey() {
    return _secureStorage.delete(key: _privateKeyStorageKey);
  }
}
