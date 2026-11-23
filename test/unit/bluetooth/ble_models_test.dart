import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';

void main() {
  group('BlePeer', () {
    test('stores peer information including deviceModel and username', () {
      const peer = BlePeer(
        peerId: 'peer-123',
        displayName: 'Omkar',
        deviceModel: 'Motorola Edge 50 Pro',
        username: 'omkar_user',
        signalStrength: -55,
      );

      expect(peer.peerId, 'peer-123');
      expect(peer.displayName, 'Omkar');
      expect(peer.deviceModel, 'Motorola Edge 50 Pro');
      expect(peer.username, 'omkar_user');
      expect(peer.signalStrength, -55);
    });

    test('supports copyWith for updating displayName and username', () {
      const peer = BlePeer(
        peerId: 'peer-123',
        displayName: 'Offlink User',
        deviceModel: 'Motorola Edge 50 Pro',
      );

      final updated = peer.copyWith(displayName: 'Alice', username: 'Alice');

      expect(updated.displayName, 'Alice');
      expect(updated.username, 'Alice');
      expect(updated.deviceModel, 'Motorola Edge 50 Pro');
      expect(updated.peerId, 'peer-123');
    });

    test('allows signal strength to be omitted', () {
      const peer = BlePeer(peerId: 'peer-123', displayName: 'Omkar');

      expect(peer.signalStrength, isNull);
      expect(peer.deviceModel, isNull);
      expect(peer.username, isNull);
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
