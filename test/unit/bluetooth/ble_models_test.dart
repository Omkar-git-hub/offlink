import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';

void main() {
  group('BlePeer', () {
    test('stores peer information', () {
      const peer = BlePeer(
        peerId: 'peer-123',
        displayName: 'Omkar',
        signalStrength: -55,
      );

      expect(peer.peerId, 'peer-123');
      expect(peer.displayName, 'Omkar');
      expect(peer.signalStrength, -55);
    });

    test('allows signal strength to be omitted', () {
      const peer = BlePeer(peerId: 'peer-123', displayName: 'Omkar');

      expect(peer.signalStrength, isNull);
    });
  });

  group('BlePacket', () {
    test('stores peer ID and payload', () {
      const packet = BlePacket(peerId: 'peer-123', payload: [1, 2, 3]);

      expect(packet.peerId, 'peer-123');
      expect(packet.payload, [1, 2, 3]);
    });
  });

  group('BleConnectionState', () {
    test('contains the expected connection states', () {
      expect(BleConnectionState.values, [
        BleConnectionState.disconnected,
        BleConnectionState.connecting,
        BleConnectionState.connected,
        BleConnectionState.disconnecting,
      ]);
    });
  });
}
