enum OfflinkMessageType {
  text,
  acknowledgement,
  encrypted,
  handshakeInit,
  handshakeResponse,
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
      default:
        throw FormatException('Unsupported Offlink message type: $value');
    }
  }
}
