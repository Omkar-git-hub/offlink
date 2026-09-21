import 'offlink_packet.dart';

class PacketCodec {
  const PacketCodec();

  String encode(OfflinkPacket packet) {
    return packet.encode();
  }

  OfflinkPacket decode(String encoded) {
    return OfflinkPacket.decode(encoded);
  }
}
