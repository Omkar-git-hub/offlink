import 'offlink_packet.dart';

abstract class PacketTransport {
  Future<void> sendPacket({
    required String peerId,
    required OfflinkPacket packet,
  });

  Stream<OfflinkPacket> get incomingPackets;

  List<String> get connectedPeerIds => const [];
}
