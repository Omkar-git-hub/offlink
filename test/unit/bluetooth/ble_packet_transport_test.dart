import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_packet_channel.dart';
import 'package:offlink/bluetooth/ble_packet_transport.dart';
import 'package:offlink/bluetooth/ble_peripheral_packet_channel.dart';
import 'package:offlink/bluetooth/flutter_blue_plus_device_connection.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';
import 'package:offlink/domain/protocol/packet_transport.dart';

class FakeBlePacketChannel implements BlePacketChannel {
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  final List<Uint8List> sentBytesList = <Uint8List>[];
  bool isInitialized = false;
  bool isDisposed = false;

  @override
  Stream<Uint8List> get incomingPackets => _incomingController.stream;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> sendBytes(Uint8List data) async {
    if (!isInitialized) {
      throw StateError('Channel not initialized');
    }
    sentBytesList.add(data);
  }

  @override
  Future<void> sendText(String value) async {
    await sendBytes(Uint8List.fromList(utf8.encode(value)));
  }

  void emit(Uint8List bytes) {
    _incomingController.add(bytes);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await _incomingController.close();
  }
}

class FakeBlePeripheralPacketChannel implements BlePeripheralPacketChannel {
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  final List<Uint8List> sentDataList = <Uint8List>[];
  bool isDisposed = false;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Future<void> sendData(Uint8List data) async {
    sentDataList.add(data);
  }

  void emit(Uint8List data) {
    _incomingController.add(data);
  }

  Future<void> dispose() async {
    isDisposed = true;
    await _incomingController.close();
  }
}

OfflinkPacket createSamplePacket({
  String messageId = 'msg-1',
  String sender = 'node-sender',
  String recipient = 'node-recipient',
  String payload = 'ping',
}) {
  return OfflinkPacket(
    version: 1,
    messageId: messageId,
    senderNodeId: sender,
    recipientNodeId: recipient,
    messageType: OfflinkMessageType.text,
    timestamp: DateTime.utc(2026, 9, 22, 10, 0),
    ttl: 3,
    payload: payload,
  );
}

void main() {
  group('BlePacketTransport', () {
    late FakeBlePacketChannel fakeCentralChannel;
    late FakeBlePeripheralPacketChannel fakePeripheralChannel;
    late FlutterBluePlusDeviceConnection connection;
    late BlePacketTransport transport;

    setUp(() {
      fakeCentralChannel = FakeBlePacketChannel();
      fakePeripheralChannel = FakeBlePeripheralPacketChannel();

      connection = FlutterBluePlusDeviceConnection(
        channelFactory: (BluetoothDevice device) => fakeCentralChannel,
      );

      transport = BlePacketTransport(
        deviceConnection: connection,
        peripheralChannel: fakePeripheralChannel,
      );
    });

    tearDown(() async {
      await transport.dispose();
      await fakeCentralChannel.dispose();
      await fakePeripheralChannel.dispose();
    });

    test('implements PacketTransport interface', () {
      expect(transport, isA<PacketTransport>());
    });

    test('initializes peer and sends packet via Central channel', () async {
      await transport.initializePeer('peer-1');
      expect(transport.hasChannel('peer-1'), isTrue);
      expect(fakeCentralChannel.isInitialized, isTrue);

      final packet = createSamplePacket(recipient: 'peer-1');
      await transport.sendPacket(peerId: 'peer-1', packet: packet);

      expect(fakeCentralChannel.sentBytesList, hasLength(1));
      final decoded = utf8.decode(fakeCentralChannel.sentBytesList.first);
      expect(decoded, contains('msg-1'));
      expect(decoded, contains('ping'));
    });

    test('decodes incoming packets from Central channel', () async {
      await transport.initializePeer('peer-1');

      final packet = createSamplePacket(messageId: 'from-central');
      final receivedFuture = transport.incomingPackets.first;

      fakeCentralChannel.emit(Uint8List.fromList(utf8.encode(packet.encode())));

      final received = await receivedFuture;
      expect(received.messageId, 'from-central');
      expect(received.payload, 'ping');
    });

    test('decodes incoming packets from Peripheral channel', () async {
      final packet = createSamplePacket(messageId: 'from-peripheral');
      final receivedFuture = transport.incomingPackets.first;

      fakePeripheralChannel.emit(
        Uint8List.fromList(utf8.encode(packet.encode())),
      );

      final received = await receivedFuture;
      expect(received.messageId, 'from-peripheral');
      expect(received.senderNodeId, 'node-sender');
    });

    test(
      'sends packet via Peripheral channel when no Central channel exists',
      () async {
        final packet = createSamplePacket(recipient: 'peer-peripheral');
        await transport.sendPacket(peerId: 'peer-peripheral', packet: packet);

        expect(fakePeripheralChannel.sentDataList, hasLength(1));
        final decoded = utf8.decode(fakePeripheralChannel.sentDataList.first);
        expect(decoded, contains('msg-1'));
        expect(decoded, contains('peer-peripheral'));
      },
    );

    test(
      'throws StateError when no Central and no Peripheral channel available',
      () async {
        final standaloneTransport = BlePacketTransport(
          deviceConnection: connection,
          peripheralChannel: null,
        );

        final packet = createSamplePacket(recipient: 'unknown-peer');

        expect(
          () => standaloneTransport.sendPacket(
            peerId: 'unknown-peer',
            packet: packet,
          ),
          throwsStateError,
        );

        await standaloneTransport.dispose();
      },
    );

    test(
      'safely ignores malformed incoming packets on Central channel',
      () async {
        await transport.initializePeer('peer-1');

        final packets = <OfflinkPacket>[];
        final subscription = transport.incomingPackets.listen(packets.add);

        fakeCentralChannel.emit(
          Uint8List.fromList(utf8.encode('malformed-json-payload')),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(packets, isEmpty);

        await subscription.cancel();
      },
    );

    test(
      'safely ignores malformed incoming packets on Peripheral channel',
      () async {
        final packets = <OfflinkPacket>[];
        final subscription = transport.incomingPackets.listen(packets.add);

        fakePeripheralChannel.emit(
          Uint8List.fromList(utf8.encode('{invalid-json: true')),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(packets, isEmpty);

        await subscription.cancel();
      },
    );

    test('removePeer disposes and removes the specific peer channel', () async {
      await transport.initializePeer('peer-1');
      expect(transport.hasChannel('peer-1'), isTrue);

      await transport.removePeer('peer-1');
      expect(transport.hasChannel('peer-1'), isFalse);
      expect(fakeCentralChannel.isDisposed, isTrue);
    });
  });
}
