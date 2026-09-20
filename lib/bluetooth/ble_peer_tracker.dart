import 'ble_models.dart';

class BlePeerTracker {
  final Map<String, BlePeer> _peers = {};

  bool add(BlePeer peer) {
    final isNewPeer = !_peers.containsKey(peer.peerId);

    _peers[peer.peerId] = peer;

    return isNewPeer;
  }

  bool remove(String peerId) {
    return _peers.remove(peerId) != null;
  }

  BlePeer? removeAndGet(String peerId) {
    return _peers.remove(peerId);
  }

  bool contains(String peerId) {
    return _peers.containsKey(peerId);
  }

  BlePeer? get(String peerId) {
    return _peers[peerId];
  }

  List<BlePeer> get peers {
    return List<BlePeer>.unmodifiable(_peers.values);
  }

  void clear() {
    _peers.clear();
  }

  Set<String> retainOnly(Set<String> peerIds) {
    final lostPeerIds = _peers.keys
        .where((peerId) => !peerIds.contains(peerId))
        .toSet();

    for (final peerId in lostPeerIds) {
      _peers.remove(peerId);
    }

    return lostPeerIds;
  }

  List<BlePeer> retainOnlyPeers(Set<String> peerIds) {
    final lostPeers = _peers.values
        .where((peer) => !peerIds.contains(peer.peerId))
        .toList();

    for (final peer in lostPeers) {
      _peers.remove(peer.peerId);
    }

    return lostPeers;
  }
}
