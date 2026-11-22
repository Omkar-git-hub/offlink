import 'package:drift/drift.dart';

/// Drift table definition for storing peer cryptographic trust and safety fingerprints.
class PeerTrustTable extends Table {
  TextColumn get peerNodeId => text()();
  TextColumn get peerPublicKey => text()();
  TextColumn get safetyFingerprint => text()();
  TextColumn get trustStatus =>
      text().withDefault(const Constant('unverified'))();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {peerNodeId};
}
