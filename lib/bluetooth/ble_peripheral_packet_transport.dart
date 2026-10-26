import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../domain/protocol/offlink_packet.dart';
import '../domain/protocol/packet_codec.dart';
import '../domain/protocol/packet_transport.dart';
import 'ble_peripheral_packet_channel.dart';

class BlePeripheralPacketTransport implements PacketTransport {
  BlePeripheralPacketTransport({
    required this.channel,
    this.codec = const PacketCodec(),
  });

  final BlePeripheralPacketChannel channel;
  final PacketCodec codec;

  final StreamController<OfflinkPacket> _incomingPackets =
      StreamController<OfflinkPacket>.broadcast();

  StreamSubscription<Uint8List>? _subscription;

  bool _initialized = false;

  @override
  Stream<OfflinkPacket> get incomingPackets => _incomingPackets.stream;

  void initialize() {
    if (_initialized) {
      return;
    }

    _initialized = true;

    _subscription = channel.incomingData.listen(_handleIncomingData);
  }

  void _handleIncomingData(Uint8List data) {
    try {
      final encoded = utf8.decode(data);
      final packet = codec.decode(encoded);

      _incomingPackets.add(packet);
    } catch (_) {
      // Ignore malformed peripheral BLE packets.
    }
  }

  @override
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  }) async {
    final encoded = codec.encode(packet);

    await channel.sendData(Uint8List.fromList(utf8.encode(encoded)));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;

    await _incomingPackets.close();
  }
}
