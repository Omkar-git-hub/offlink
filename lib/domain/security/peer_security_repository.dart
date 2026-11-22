import 'trust_status.dart';

abstract interface class PeerSecurityRepository {
  Future<void> blockPeer(String nodeId, {String reason = 'manual'});

  Future<void> unblockPeer(String nodeId);

  Future<bool> isPeerBlocked(String nodeId);

  bool isPeerBlockedSync(String nodeId);

  Future<List<BlockedPeer>> getBlockedPeers();

  Stream<List<BlockedPeer>> watchBlockedPeers();

  Future<PeerTrust?> getPeerTrust(String peerNodeId);

  Future<void> saveOrUpdatePeerTrust(PeerTrust trust);

  Future<void> setPeerVerificationStatus(String peerNodeId, TrustStatus status);
}
