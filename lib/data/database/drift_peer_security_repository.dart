import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/security/peer_security_repository.dart';
import '../../domain/security/trust_status.dart';
import 'offlink_database.dart';

class DriftPeerSecurityRepository implements PeerSecurityRepository {
  DriftPeerSecurityRepository(this._db) {
    _initCache();
  }

  final OfflinkDatabase _db;
  final Set<String> _cachedBlockedPeerIds = <String>{};
  StreamSubscription<List<BlockedPeer>>? _cacheSubscription;

  void _initCache() {
    _cacheSubscription = watchBlockedPeers().listen((peers) {
      _cachedBlockedPeerIds.clear();
      _cachedBlockedPeerIds.addAll(peers.map((p) => p.nodeId));
    });
  }

  void dispose() {
    _cacheSubscription?.cancel();
  }

  @override
  Future<void> blockPeer(String nodeId, {String reason = 'manual'}) async {
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.blockedPeersTable)
        .insertOnConflictUpdate(
          BlockedPeersTableCompanion.insert(
            nodeId: nodeId,
            blockedAt: now,
            reason: Value(reason),
          ),
        );
    _cachedBlockedPeerIds.add(nodeId);
  }

  @override
  Future<void> unblockPeer(String nodeId) async {
    await (_db.delete(
      _db.blockedPeersTable,
    )..where((t) => t.nodeId.equals(nodeId))).go();
    _cachedBlockedPeerIds.remove(nodeId);
  }

  @override
  Future<bool> isPeerBlocked(String nodeId) async {
    final query = _db.select(_db.blockedPeersTable)
      ..where((t) => t.nodeId.equals(nodeId));
    final row = await query.getSingleOrNull();
    if (row != null) {
      _cachedBlockedPeerIds.add(nodeId);
      return true;
    }
    _cachedBlockedPeerIds.remove(nodeId);
    return false;
  }

  @override
  bool isPeerBlockedSync(String nodeId) =>
      _cachedBlockedPeerIds.contains(nodeId);

  @override
  Future<List<BlockedPeer>> getBlockedPeers() async {
    final query = _db.select(_db.blockedPeersTable)
      ..orderBy([(t) => OrderingTerm.desc(t.blockedAt)]);
    final rows = await query.get();
    return rows
        .map(
          (r) => BlockedPeer(
            nodeId: r.nodeId,
            blockedAt: r.blockedAt,
            reason: r.reason,
          ),
        )
        .toList();
  }

  @override
  Stream<List<BlockedPeer>> watchBlockedPeers() {
    final query = _db.select(_db.blockedPeersTable)
      ..orderBy([(t) => OrderingTerm.desc(t.blockedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => BlockedPeer(
              nodeId: r.nodeId,
              blockedAt: r.blockedAt,
              reason: r.reason,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<PeerTrust?> getPeerTrust(String peerNodeId) async {
    final query = _db.select(_db.peerTrustTable)
      ..where((t) => t.peerNodeId.equals(peerNodeId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return PeerTrust(
      peerNodeId: row.peerNodeId,
      peerPublicKey: row.peerPublicKey,
      safetyFingerprint: row.safetyFingerprint,
      trustStatus: TrustStatus.fromString(row.trustStatus),
      verifiedAt: row.verifiedAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> saveOrUpdatePeerTrust(PeerTrust trust) async {
    await _db
        .into(_db.peerTrustTable)
        .insertOnConflictUpdate(
          PeerTrustTableCompanion.insert(
            peerNodeId: trust.peerNodeId,
            peerPublicKey: trust.peerPublicKey,
            safetyFingerprint: trust.safetyFingerprint,
            trustStatus: Value(trust.trustStatus.name),
            verifiedAt: Value(trust.verifiedAt),
            updatedAt: trust.updatedAt,
          ),
        );
  }

  @override
  Future<void> setPeerVerificationStatus(
    String peerNodeId,
    TrustStatus status,
  ) async {
    final now = DateTime.now().toUtc();
    final verifiedAt = status == TrustStatus.verified ? now : null;

    final updateStatement = _db.update(_db.peerTrustTable)
      ..where((t) => t.peerNodeId.equals(peerNodeId));

    await updateStatement.write(
      PeerTrustTableCompanion(
        trustStatus: Value(status.name),
        verifiedAt: Value(verifiedAt),
        updatedAt: Value(now),
      ),
    );
  }
}
