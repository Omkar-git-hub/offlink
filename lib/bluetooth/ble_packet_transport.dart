// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../domain/protocol/offlink_packet.dart';
import '../domain/protocol/packet_codec.dart';
import '../domain/protocol/packet_transport.dart';
import 'ble_packet_channel.dart';
import 'ble_peripheral_packet_channel.dart';
import 'flutter_blue_plus_device_connection.dart';

class BlePacketTransport implements PacketTransport {
  BlePacketTransport({
    required FlutterBluePlusDeviceConnection deviceConnection,
    BlePeripheralPacketChannel? peripheralChannel,
    PacketCodec codec = const PacketCodec(),
  }) : _deviceConnection = deviceConnection,
       _peripheralChannel = peripheralChannel,
       _codec = codec {
    _initializePeripheral();
  }

  final FlutterBluePlusDeviceConnection _deviceConnection;
  final BlePeripheralPacketChannel? _peripheralChannel;
  final PacketCodec _codec;

  final StreamController<OfflinkPacket> _incomingPackets =
      StreamController<OfflinkPacket>.broadcast();

  final Map<String, BlePacketChannel> _channels = <String, BlePacketChannel>{};
  StreamSubscription<Uint8List>? _peripheralSubscription;

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingPackets.stream;

  void _initializePeripheral() {
    final peripheral = _peripheralChannel;
    if (peripheral == null) {
      return;
    }

    _peripheralSubscription = peripheral.incomingData.listen((bytes) {
      try {
        final encoded = utf8.decode(bytes);
        final packet = _codec.decode(encoded);

        _incomingPackets.add(packet);
      } catch (_) {
        // Ignore malformed peripheral BLE packets safely.
      }
    });
  }

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
        // Ignore malformed BLE packets safely.
      }
    });
  }

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    final channel = _channels[peerId];

    if (channel != null) {
      final encoded = _codec.encode(packet);
      await channel.sendBytes(Uint8List.fromList(utf8.encode(encoded)));
      return;
    }

    final peripheral = _peripheralChannel;
    if (peripheral != null) {
      final encoded = _codec.encode(packet);
      await peripheral.sendData(Uint8List.fromList(utf8.encode(encoded)));
      return;
    }

    throw StateError('BLE packet channel is not initialized for peer: $peerId');
  }

  Future<void> removePeer(String peerId) async {
    final channel = _channels.remove(peerId);

    await channel?.dispose();
  }

  bool hasChannel(String peerId) => _channels.containsKey(peerId);

  Future<void> dispose() async {
    for (final channel in _channels.values) {
      await channel.dispose();
    }

    _channels.clear();

    await _peripheralSubscription?.cancel();
    _peripheralSubscription = null;

    await _incomingPackets.close();
  }
}
