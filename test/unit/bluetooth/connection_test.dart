import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/connection.dart';
import 'package:offlink/bluetooth/ble_models.dart';

class FakeBleConnection implements BleConnection {
  bool connected = false;
  bool disconnected = false;

  @override
  Future<void> connect(BlePeer peer) async {
    connected = true;
  }

  @override
  Future<void> disconnect(String peerId) async {
    disconnected = true;
  }

  @override
  Stream<BleConnectionState> get connectionStates =>
      const Stream<BleConnectionState>.empty();
}

void main() {
  group('BleConnection', () {
    test('can connect to a peer', () async {
      final connection = FakeBleConnection();
      const peer = BlePeer(peerId: 'peer-123', displayName: 'Omkar');

      await connection.connect(peer);

      expect(connection.connected, isTrue);
    });

    test('can disconnect from a peer', () async {
      final connection = FakeBleConnection();

      await connection.disconnect('peer-123');

      expect(connection.disconnected, isTrue);
    });

    test('exposes connection state stream', () {
      final connection = FakeBleConnection();

      expect(connection.connectionStates, isA<Stream<BleConnectionState>>());
    });
  });
}
