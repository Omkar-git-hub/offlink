import 'offlink_packet.dart';

abstract interface class PacketTransport {
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  });

  Stream<OfflinkPacket> get incomingPackets;
}
