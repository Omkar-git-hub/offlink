import '../../core/identity/node_id_generator.dart';
import '../../crypto/identity/identity_key_service.dart';
import 'offlink_identity.dart';

class IdentityInitializationService {
  IdentityInitializationService({
    NodeIdGenerator? nodeIdGenerator,
    IdentityKeyService? keyService,
  })  : _nodeIdGenerator = nodeIdGenerator ?? NodeIdGenerator(),
        _keyService = keyService ?? IdentityKeyService();

  final NodeIdGenerator _nodeIdGenerator;
  final IdentityKeyService _keyService;

  Future<OfflinkIdentity> createIdentity({
    required String username,
  }) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty) {
      throw ArgumentError('Username cannot be empty.');
    }

    final nodeId = _nodeIdGenerator.generate();
    final keyPair = await _keyService.generateKeyPair();

    final publicKeyBytes = await _keyService.exportPublicKey(
      keyPair.publicKey,
    );

    await _keyService.storePrivateKey(
      keyPair.privateKey,
    );

    return OfflinkIdentity(
      nodeId: nodeId,
      username: normalizedUsername,
      publicKey: _encodePublicKey(publicKeyBytes),
      createdAt: DateTime.now().toUtc(),
    );
  }

  String _encodePublicKey(List<int> bytes) {
    return bytes
        .map(
          (byte) => byte.toRadixString(16).padLeft(2, '0'),
        )
        .join();
  }
}