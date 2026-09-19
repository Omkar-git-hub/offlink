import 'identity_initialization_service.dart';
import 'identity_repository.dart';
import 'offlink_identity.dart';
import '../../crypto/identity/identity_key_service.dart';

class IdentityManager {
  IdentityManager({
    required this.repository,
    required this.initializationService,
    required this.keyService,
  });

  final IdentityRepository repository;
  final IdentityInitializationService initializationService;
  final IdentityKeyService keyService;

  Future<OfflinkIdentity?> loadExistingIdentity() {
    return repository.loadIdentity();
  }

  Future<bool> hasIdentity() {
    return repository.hasIdentity();
  }

  Future<OfflinkIdentity> createIdentity({required String username}) async {
    final existingIdentity = await repository.loadIdentity();

    if (existingIdentity != null) {
      throw StateError('Identity already exists.');
    }

    final identity = await initializationService.createIdentity(
      username: username,
    );

    try {
      await repository.saveIdentity(identity);
    } catch (_) {
      // Identity metadata was not persisted successfully.
      // Remove the private key so we don't leave behind
      // an unusable partial identity.
      await keyService.deletePrivateKey();
      rethrow;
    }

    return identity;
  }

  Future<OfflinkIdentity?> loadAndValidateIdentity() async {
    final identity = await repository.loadIdentity();

    if (identity == null) {
      return null;
    }

    final privateKeyPublicKey = await keyService.loadPrivateKeyPublicKey();

    if (privateKeyPublicKey == null) {
      throw StateError('Identity metadata exists but private key is missing.');
    }

    final storedPublicKey = _decodeHex(identity.publicKey);

    if (!_bytesEqual(privateKeyPublicKey.bytes, storedPublicKey)) {
      throw StateError('Identity metadata and private key do not match.');
    }

    return identity;
  }

  Future<void> updateUsername(String username) {
    return repository.updateUsername(username);
  }

  Future<void> clearIdentity() async {
    await repository.clearIdentity();
    await keyService.deletePrivateKey();
  }

  List<int> _decodeHex(String value) {
    if (value.length.isOdd) {
      throw StateError('Stored public key has invalid hexadecimal length.');
    }

    final bytes = <int>[];

    for (var index = 0; index < value.length; index += 2) {
      final byte = int.tryParse(value.substring(index, index + 2), radix: 16);

      if (byte == null) {
        throw StateError(
          'Stored public key contains invalid hexadecimal data.',
        );
      }

      bytes.add(byte);
    }

    return bytes;
  }

  bool _bytesEqual(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }
}
