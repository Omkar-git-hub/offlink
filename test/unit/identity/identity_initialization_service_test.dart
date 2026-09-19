import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';

import 'fakes/fake_secure_key_storage.dart';

void main() {
  group('IdentityInitializationService', () {
    late FakeSecureKeyStorage storage;
    late IdentityKeyService keyService;
    late IdentityInitializationService service;

    setUp(() {
      storage = FakeSecureKeyStorage();

      keyService = IdentityKeyService(secureStorage: storage);

      service = IdentityInitializationService(
        nodeIdGenerator: NodeIdGenerator(),
        keyService: keyService,
      );
    });

    test('creates an identity with the supplied username', () async {
      final identity = await service.createIdentity(username: 'Omkar');

      expect(identity.username, 'Omkar');
      expect(identity.nodeId, isNotEmpty);
      expect(identity.publicKey, isNotEmpty);
      expect(identity.createdAt, isNotNull);
    });

    test('trims username before creating identity', () async {
      final identity = await service.createIdentity(username: '  Omkar  ');

      expect(identity.username, 'Omkar');
    });

    test('rejects an empty username', () async {
      expect(
        () => service.createIdentity(username: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('creates a private key in secure storage', () async {
      await service.createIdentity(username: 'Omkar');

      expect(await keyService.hasPrivateKey(), isTrue);

      expect(await keyService.loadPrivateKey(), isNotNull);
    });

    test('creates a public key matching the stored private key', () async {
      final identity = await service.createIdentity(username: 'Omkar');

      final restoredPublicKey = await keyService.loadPrivateKeyPublicKey();

      expect(restoredPublicKey, isNotNull);

      expect(restoredPublicKey!.bytes, equals(_decodeHex(identity.publicKey)));
    });
  });
}

List<int> _decodeHex(String value) {
  if (value.length.isOdd) {
    throw StateError('Invalid hexadecimal length.');
  }

  final bytes = <int>[];

  for (var index = 0; index < value.length; index += 2) {
    final byte = int.tryParse(value.substring(index, index + 2), radix: 16);

    if (byte == null) {
      throw StateError('Invalid hexadecimal value.');
    }

    bytes.add(byte);
  }

  return bytes;
}
