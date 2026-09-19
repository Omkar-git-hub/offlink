import 'offlink_identity.dart';

abstract interface class IdentityRepository {
  Future<OfflinkIdentity?> loadIdentity();

  Future<void> saveIdentity(OfflinkIdentity identity);

  Future<void> updateUsername(String username);

  Future<bool> hasIdentity();

  Future<void> clearIdentity();
}
