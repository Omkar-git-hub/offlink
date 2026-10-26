import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/bluetooth/ble_peripheral_packet_channel.dart';
import 'package:offlink/bluetooth/ble_peripheral_packet_transport.dart';
import 'package:offlink/domain/protocol/offlink_message_type.dart';
import 'package:offlink/domain/protocol/offlink_packet.dart';

class FakeBlePeripheralPacketChannel implements BlePeripheralPacketChannel {
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>.broadcast();

  final List<Uint8List> sentData = <Uint8List>[];

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Future<void> sendData(Uint8List data) async {
    sentData.add(data);
  }

  void emit(Uint8List data) {
    _incomingController.add(data);
  }

  Future<void> dispose() async {
    await _incomingController.close();
  }
}

OfflinkPacket createTestPacket() {
  return OfflinkPacket(
    version: 1,
    messageId: 'message-1',
    senderNodeId: 'node-a',
    recipientNodeId: 'node-b',
    messageType: OfflinkMessageType.text,
    timestamp: DateTime.utc(2026, 9, 21, 12, 0),
    ttl: 5,
    payload: 'hello',
  );
}

void main() {
  test('sends encoded packet through peripheral channel', () async {
    final channel = FakeBlePeripheralPacketChannel();
    final transport = BlePeripheralPacketTransport(channel: channel);

    final packet = createTestPacket();

    await transport.sendPacket(peerId: 'node-b', packet: packet);

    expect(channel.sentData, hasLength(1));
    expect(channel.sentData.first, isNotEmpty);

    await transport.dispose();
    await channel.dispose();
  });

  test('decodes incoming BLE data into an OfflinkPacket', () async {
    final channel = FakeBlePeripheralPacketChannel();
    final transport = BlePeripheralPacketTransport(channel: channel);

    transport.initialize();

    final packet = createTestPacket();
    final encoded = packet.encode();

    final receivedFuture = transport.incomingPackets.first;

    channel.emit(Uint8List.fromList(encoded.codeUnits));

    final received = await receivedFuture;

    expect(received.messageId, packet.messageId);
    expect(received.senderNodeId, packet.senderNodeId);
    expect(received.recipientNodeId, packet.recipientNodeId);
    expect(received.payload, packet.payload);
    expect(received.ttl, packet.ttl);

    await transport.dispose();
    await channel.dispose();
  });

  test('ignores malformed incoming BLE data', () async {
    final channel = FakeBlePeripheralPacketChannel();
    final transport = BlePeripheralPacketTransport(channel: channel);

    transport.initialize();

    final packets = <OfflinkPacket>[];
    final subscription = transport.incomingPackets.listen(packets.add);

    channel.emit(Uint8List.fromList('not-a-valid-offlink-packet'.codeUnits));

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(packets, isEmpty);

    await subscription.cancel();
    await transport.dispose();
    await channel.dispose();
  });

  test('initialize is idempotent', () async {
    final channel = FakeBlePeripheralPacketChannel();
    final transport = BlePeripheralPacketTransport(channel: channel);

    transport.initialize();
    transport.initialize();

    final packet = createTestPacket();
    final receivedFuture = transport.incomingPackets.first;

    channel.emit(Uint8List.fromList(packet.encode().codeUnits));

    final received = await receivedFuture;

    expect(received.messageId, packet.messageId);

    await transport.dispose();
    await channel.dispose();
  });
}
