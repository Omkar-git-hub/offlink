enum OfflinkMessageType {
  text,
  acknowledgement,
  encrypted,
  handshakeInit,
  handshakeResponse,
  groupMessage,
  groupMembership,
  location,
}

extension OfflinkMessageTypeCodec on OfflinkMessageType {
  String get value {
    switch (this) {
      case OfflinkMessageType.text:
        return 'text';
      case OfflinkMessageType.acknowledgement:
        return 'ack';
      case OfflinkMessageType.encrypted:
        return 'enc';
      case OfflinkMessageType.handshakeInit:
        return 'handshake_init';
      case OfflinkMessageType.handshakeResponse:
        return 'handshake_resp';
      case OfflinkMessageType.groupMessage:
        return 'group_msg';
      case OfflinkMessageType.groupMembership:
        return 'group_member';
      case OfflinkMessageType.location:
        return 'loc';
    }
  }

  static OfflinkMessageType fromValue(String value) {
    switch (value) {
      case 'text':
        return OfflinkMessageType.text;
      case 'ack':
        return OfflinkMessageType.acknowledgement;
      case 'enc':
        return OfflinkMessageType.encrypted;
      case 'handshake_init':
        return OfflinkMessageType.handshakeInit;
      case 'handshake_resp':
        return OfflinkMessageType.handshakeResponse;
      case 'group_msg':
        return OfflinkMessageType.groupMessage;
      case 'group_member':
        return OfflinkMessageType.groupMembership;
      case 'loc':
        return OfflinkMessageType.location;
      default:
        throw FormatException('Unsupported Offlink message type: $value');
    }
  }
}
