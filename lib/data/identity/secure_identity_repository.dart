import 'dart:convert';

import '../../domain/identity/identity_repository.dart';
import '../../domain/identity/offlink_identity.dart';
import 'flutter_secure_identity_storage.dart';
import 'secure_identity_storage.dart';

class SecureIdentityRepository implements IdentityRepository {
  SecureIdentityRepository({SecureIdentityStorage? storage})
    : _storage = storage ?? FlutterSecureIdentityStorage();

  static const _identityKey = 'offlink_identity';

  final SecureIdentityStorage _storage;

  @override
  Future<OfflinkIdentity?> loadIdentity() async {
    final encoded = await _storage.read(key: _identityKey);

    if (encoded == null) {
      return null;
    }

    final json = jsonDecode(encoded) as Map<String, dynamic>;

    return OfflinkIdentity(
      nodeId: json['nodeId'] as String,
      username: json['username'] as String,
      publicKey: json['publicKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  Future<void> saveIdentity(OfflinkIdentity identity) async {
    final encoded = jsonEncode({
      'nodeId': identity.nodeId,
      'username': identity.username,
      'publicKey': identity.publicKey,
      'createdAt': identity.createdAt.toIso8601String(),
    });

    await _storage.write(key: _identityKey, value: encoded);
  }

  @override
  Future<void> updateUsername(String username) async {
    final identity = await loadIdentity();

    if (identity == null) {
      throw StateError('Cannot update username before identity exists.');
    }

    await saveIdentity(identity.copyWith(username: username.trim()));
  }

  @override
  Future<bool> hasIdentity() {
    return _storage.containsKey(key: _identityKey);
  }

  @override
  Future<void> clearIdentity() {
    return _storage.delete(key: _identityKey);
  }
}
