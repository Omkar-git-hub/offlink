import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/ble_peer_tracker.dart';

void main() {
  late BlePeerTracker tracker;

  const peer = BlePeer(
    peerId: 'peer-001',
    displayName: 'Test User',
    signalStrength: -50,
  );

  setUp(() {
    tracker = BlePeerTracker();
  });

  test('adds a new peer and reports it as new', () {
    final isNewPeer = tracker.add(peer);

    expect(isNewPeer, isTrue);
    expect(tracker.contains(peer.peerId), isTrue);
    expect(tracker.get(peer.peerId), peer);
  });

  test('adding an existing peer reports it as not new', () {
    tracker.add(peer);

    final isNewPeer = tracker.add(peer);

    expect(isNewPeer, isFalse);
    expect(tracker.peers, [peer]);
  });

  test('removes an existing peer', () {
    tracker.add(peer);

    final removed = tracker.remove(peer.peerId);

    expect(removed, isTrue);
    expect(tracker.contains(peer.peerId), isFalse);
    expect(tracker.get(peer.peerId), isNull);
  });

  test('removing an unknown peer returns false', () {
    final removed = tracker.remove('unknown-peer');

    expect(removed, isFalse);
  });

  test('peers returns all tracked peers', () {
    const secondPeer = BlePeer(
      peerId: 'peer-002',
      displayName: 'Second User',
      signalStrength: -60,
    );

    tracker.add(peer);
    tracker.add(secondPeer);

    expect(tracker.peers, [peer, secondPeer]);
  });

  test('clear removes all tracked peers', () {
    tracker.add(peer);

    tracker.clear();

    expect(tracker.peers, isEmpty);
  });

  test('retainOnly removes peers that are not present', () {
    const secondPeer = BlePeer(
      peerId: 'peer-002',
      displayName: 'Second User',
      signalStrength: -60,
    );

    tracker.add(peer);
    tracker.add(secondPeer);

    final lostPeerIds = tracker.retainOnly({'peer-001'});

    expect(lostPeerIds, {'peer-002'});
    expect(tracker.peers, [peer]);
  });

  test('retainOnly keeps all peers that are present', () {
    const secondPeer = BlePeer(
      peerId: 'peer-002',
      displayName: 'Second User',
      signalStrength: -60,
    );

    tracker.add(peer);
    tracker.add(secondPeer);

    final lostPeerIds = tracker.retainOnly({'peer-001', 'peer-002'});

    expect(lostPeerIds, isEmpty);
    expect(tracker.peers, [peer, secondPeer]);
  });

  test('retainOnly removes all peers when no peers are present', () {
    tracker.add(peer);

    final lostPeerIds = tracker.retainOnly({});

    expect(lostPeerIds, {'peer-001'});
    expect(tracker.peers, isEmpty);
  });
}
