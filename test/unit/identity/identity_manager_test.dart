import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/crypto/identity/identity_key_service.dart';
import 'package:offlink/domain/identity/identity_initialization_service.dart';
import 'package:offlink/domain/identity/identity_manager.dart';
import 'package:offlink/domain/identity/identity_repository.dart';
import 'package:offlink/domain/identity/offlink_identity.dart';

import 'fakes/fake_secure_identity_storage.dart';
import 'fakes/fake_secure_key_storage.dart';

class FailingIdentityRepository implements IdentityRepository {
  @override
  Future<OfflinkIdentity?> loadIdentity() async {
    return null;
  }

  @override
  Future<void> saveIdentity(OfflinkIdentity identity) async {
    throw StateError('Identity persistence failed.');
  }

  @override
  Future<void> updateUsername(String username) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> hasIdentity() async {
    return false;
  }

  @override
  Future<void> clearIdentity() async {
    throw UnimplementedError();
  }
}

class TestIdentityRepository implements IdentityRepository {
  TestIdentityRepository({required this._storage});

  static const _identityKey = 'test_identity';

  final FakeSecureIdentityStorage _storage;

  OfflinkIdentity? _identity;

  @override
  Future<OfflinkIdentity?> loadIdentity() async {
    return _identity;
  }

  @override
  Future<void> saveIdentity(OfflinkIdentity identity) async {
    _identity = identity;

    await _storage.write(key: _identityKey, value: identity.nodeId);
  }

  @override
  Future<void> updateUsername(String username) async {
    if (_identity == null) {
      throw StateError('Identity does not exist.');
    }

    _identity = _identity!.copyWith(username: username.trim());
  }

  @override
  Future<bool> hasIdentity() async {
    return _identity != null;
  }

  @override
  Future<void> clearIdentity() async {
    _identity = null;

    await _storage.delete(key: _identityKey);
  }
}

void main() {
  late FakeSecureKeyStorage keyStorage;
  late IdentityKeyService keyService;
  late IdentityInitializationService initializationService;
  late IdentityManager manager;

  setUp(() {
    keyStorage = FakeSecureKeyStorage();

    keyService = IdentityKeyService(secureStorage: keyStorage);

    initializationService = IdentityInitializationService(
      keyService: keyService,
    );
  });

  test('creates identity successfully', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    final identity = await manager.createIdentity(username: 'Omkar');

    expect(identity.username, 'Omkar');
    expect(identity.nodeId, isNotEmpty);
    expect(identity.publicKey, isNotEmpty);
    expect(identity.createdAt, isNotNull);

    expect(await keyService.hasPrivateKey(), isTrue);

    expect(await repository.hasIdentity(), isTrue);
  });

  test('does not create a second identity', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    await manager.createIdentity(username: 'Omkar');

    await expectLater(
      manager.createIdentity(username: 'AnotherUser'),
      throwsA(isA<StateError>()),
    );
  });

  test('loads existing identity', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    final createdIdentity = await manager.createIdentity(username: 'Omkar');

    final loadedIdentity = await manager.loadExistingIdentity();

    expect(loadedIdentity, isNotNull);

    expect(loadedIdentity!.nodeId, createdIdentity.nodeId);

    expect(loadedIdentity.username, 'Omkar');

    expect(loadedIdentity.publicKey, createdIdentity.publicKey);
  });

  test('validates identity when private key matches', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    final createdIdentity = await manager.createIdentity(username: 'Omkar');

    final validatedIdentity = await manager.loadAndValidateIdentity();

    expect(validatedIdentity, isNotNull);

    expect(validatedIdentity!.nodeId, createdIdentity.nodeId);
  });

  test('fails validation when private key is missing', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    await manager.createIdentity(username: 'Omkar');

    await keyService.deletePrivateKey();

    await expectLater(
      manager.loadAndValidateIdentity(),
      throwsA(isA<StateError>()),
    );
  });

  test('clears identity and private key', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    await manager.createIdentity(username: 'Omkar');

    expect(await repository.hasIdentity(), isTrue);

    expect(await keyService.hasPrivateKey(), isTrue);

    await manager.clearIdentity();

    expect(await repository.hasIdentity(), isFalse);

    expect(await keyService.hasPrivateKey(), isFalse);
  });

  test('updates username', () async {
    final repository = TestIdentityRepository(
      storage: FakeSecureIdentityStorage(),
    );

    manager = IdentityManager(
      repository: repository,
      initializationService: initializationService,
      keyService: keyService,
    );

    final identity = await manager.createIdentity(username: 'Omkar');

    await manager.updateUsername('NewName');

    final updatedIdentity = await manager.loadExistingIdentity();

    expect(updatedIdentity, isNotNull);

    expect(updatedIdentity!.username, 'NewName');

    expect(updatedIdentity.nodeId, identity.nodeId);

    expect(updatedIdentity.publicKey, identity.publicKey);
  });

  test('removes private key when identity persistence fails', () async {
    final failingRepository = FailingIdentityRepository();

    manager = IdentityManager(
      repository: failingRepository,
      initializationService: initializationService,
      keyService: keyService,
    );

    await expectLater(
      manager.createIdentity(username: 'Omkar'),
      throwsA(isA<StateError>()),
    );

    expect(await keyService.hasPrivateKey(), isFalse);
  });
}
