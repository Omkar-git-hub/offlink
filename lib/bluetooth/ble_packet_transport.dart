// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import '../domain/protocol/offlink_packet.dart';
import '../domain/protocol/packet_codec.dart';
import '../domain/protocol/packet_transport.dart';
import 'ble_packet_channel.dart';
import 'flutter_blue_plus_device_connection.dart';

class BlePacketTransport implements PacketTransport {
  BlePacketTransport({
    required FlutterBluePlusDeviceConnection deviceConnection,
    PacketCodec codec = const PacketCodec(),
  }) : _deviceConnection = deviceConnection,
       _codec = codec;

  final FlutterBluePlusDeviceConnection _deviceConnection;
  final PacketCodec _codec;

  final StreamController<OfflinkPacket> _incomingPackets =
      StreamController<OfflinkPacket>.broadcast();

  final Map<String, BlePacketChannel> _channels = <String, BlePacketChannel>{};

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingPackets.stream;

  Future<void> initializePeer(String peerId) async {
    final channel = await _deviceConnection.createPacketChannel(peerId);

    await channel.initialize();

    await _channels[peerId]?.dispose();

    _channels[peerId] = channel;

    channel.incomingPackets.listen((bytes) {
      try {
        final encoded = utf8.decode(bytes);
        final packet = _codec.decode(encoded);

        _incomingPackets.add(packet);
      } catch (_) {
        // Ignore malformed BLE packets.
      }
    });
  }

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    final channel = _channels[peerId];

    if (channel == null) {
      throw StateError(
        'BLE packet channel is not initialized for peer: $peerId',
      );
    }

    final encoded = _codec.encode(packet);

    await channel.sendBytes(utf8.encode(encoded));
  }

  Future<void> removePeer(String peerId) async {
    final channel = _channels.remove(peerId);

    await channel?.dispose();
  }

  Future<void> dispose() async {
    for (final channel in _channels.values) {
      await channel.dispose();
    }

    _channels.clear();

    await _incomingPackets.close();
  }
}
