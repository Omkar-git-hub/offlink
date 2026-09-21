import 'offlink_packet.dart';
import 'protocol_version.dart';

class PacketValidator {
  const PacketValidator({this.maxTtl = 16, this.maxPayloadLength = 4096});

  final int maxTtl;
  final int maxPayloadLength;

  bool isValid(OfflinkPacket packet) {
    if (packet.version != ProtocolVersion.current) {
      return false;
    }

    if (packet.messageId.trim().isEmpty) {
      return false;
    }

    if (packet.senderNodeId.trim().isEmpty) {
      return false;
    }

    if (packet.recipientNodeId.trim().isEmpty) {
      return false;
    }

    if (packet.ttl < 0 || packet.ttl > maxTtl) {
      return false;
    }

    if (packet.payload.length > maxPayloadLength) {
      return false;
    }

    return true;
  }
}
