import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/data/identity/secure_identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';

import 'fakes/fake_secure_identity_storage.dart';

void main() {
  group('SecureIdentityRepository', () {
    late FakeSecureIdentityStorage storage;
    late SecureIdentityRepository repository;

    final identity = OfflinkIdentity(
      nodeId: '0123456789abcdef0123456789abcdef',
      username: 'Omkar',
      publicKey: 'public-key',
      createdAt: DateTime.utc(2026, 9, 19, 12),
    );

    setUp(() {
      storage = FakeSecureIdentityStorage();
      repository = SecureIdentityRepository(storage: storage);
    });

    test('returns null when identity does not exist', () async {
      final result = await repository.loadIdentity();

      expect(result, isNull);
    });

    test('saves and loads identity', () async {
      await repository.saveIdentity(identity);

      final result = await repository.loadIdentity();

      expect(result, isNotNull);
      expect(result!.nodeId, identity.nodeId);
      expect(result.username, identity.username);
      expect(result.publicKey, identity.publicKey);
      expect(result.createdAt, identity.createdAt);
    });

    test('reports whether identity exists', () async {
      expect(await repository.hasIdentity(), isFalse);

      await repository.saveIdentity(identity);

      expect(await repository.hasIdentity(), isTrue);
    });

    test('updates username without changing identity', () async {
      await repository.saveIdentity(identity);

      await repository.updateUsername('  Rahul  ');

      final result = await repository.loadIdentity();

      expect(result, isNotNull);
      expect(result!.username, 'Rahul');
      expect(result.nodeId, identity.nodeId);
      expect(result.publicKey, identity.publicKey);
      expect(result.createdAt, identity.createdAt);
    });

    test('rejects username update when identity does not exist', () async {
      expect(() => repository.updateUsername('Rahul'), throwsStateError);
    });

    test('clears identity', () async {
      await repository.saveIdentity(identity);

      expect(await repository.hasIdentity(), isTrue);

      await repository.clearIdentity();

      expect(await repository.hasIdentity(), isFalse);

      expect(await repository.loadIdentity(), isNull);
    });
  });
}
