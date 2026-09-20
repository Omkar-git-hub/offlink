import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_models.dart';
import 'package:offlink/bluetooth/phone_ble_connection.dart';

import 'fakes/fake_ble_device_connection.dart';

void main() {
  late FakeBleDeviceConnection fakeDeviceConnection;
  late PhoneBleConnection phoneBleConnection;

  const peer = BlePeer(
    peerId: 'peer-001',
    displayName: 'Test User',
    signalStrength: -50,
  );

  setUp(() {
    fakeDeviceConnection = FakeBleDeviceConnection();

    phoneBleConnection = PhoneBleConnection(
      deviceConnection: fakeDeviceConnection,
    );
  });

  tearDown(() async {
    await phoneBleConnection.dispose();
  });

  test('connect emits connecting then connected', () async {
    final states = <BleConnectionState>[];

    final subscription = phoneBleConnection.connectionStates.listen(states.add);

    await phoneBleConnection.connect(peer);
    await Future<void>.delayed(Duration.zero);

    expect(states, [
      BleConnectionState.connecting,
      BleConnectionState.connected,
    ]);

    expect(fakeDeviceConnection.connectCalled, isTrue);
    expect(fakeDeviceConnection.connectedPeer, peer);

    await subscription.cancel();
  });

  test('failed connect emits connecting then disconnected', () async {
    final error = Exception('Connection failed');

    fakeDeviceConnection.connectError = error;

    final states = <BleConnectionState>[];

    final subscription = phoneBleConnection.connectionStates.listen(states.add);

    await expectLater(phoneBleConnection.connect(peer), throwsA(same(error)));

    await Future<void>.delayed(Duration.zero);

    expect(states, [
      BleConnectionState.connecting,
      BleConnectionState.disconnected,
    ]);

    expect(fakeDeviceConnection.connectCalled, isTrue);

    await subscription.cancel();
  });

  test('disconnect emits disconnecting then disconnected', () async {
    await phoneBleConnection.connect(peer);
    await Future<void>.delayed(Duration.zero);

    final states = <BleConnectionState>[];

    final subscription = phoneBleConnection.connectionStates.listen(states.add);

    await phoneBleConnection.disconnect(peer.peerId);
    await Future<void>.delayed(Duration.zero);

    expect(states, [
      BleConnectionState.disconnecting,
      BleConnectionState.disconnected,
    ]);

    expect(fakeDeviceConnection.disconnectCalled, isTrue);
    expect(fakeDeviceConnection.disconnectedPeer, peer);

    await subscription.cancel();
  });

  test('disconnecting unknown peer does nothing', () async {
    final states = <BleConnectionState>[];

    final subscription = phoneBleConnection.connectionStates.listen(states.add);

    await phoneBleConnection.disconnect('unknown-peer');
    await Future<void>.delayed(Duration.zero);

    expect(states, isEmpty);
    expect(fakeDeviceConnection.disconnectCalled, isFalse);

    await subscription.cancel();
  });

  test('dispose disconnects connected peers', () async {
    await phoneBleConnection.connect(peer);
    await Future<void>.delayed(Duration.zero);

    await phoneBleConnection.dispose();

    expect(fakeDeviceConnection.disconnectCalled, isTrue);
    expect(fakeDeviceConnection.disconnectedPeer, peer);
  });
}
