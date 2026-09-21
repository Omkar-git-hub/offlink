enum OfflinkMessageType { text, acknowledgement }

extension OfflinkMessageTypeCodec on OfflinkMessageType {
  String get value {
    switch (this) {
      case OfflinkMessageType.text:
        return 'text';
      case OfflinkMessageType.acknowledgement:
        return 'ack';
    }
  }

  static OfflinkMessageType fromValue(String value) {
    switch (value) {
      case 'text':
        return OfflinkMessageType.text;
      case 'ack':
        return OfflinkMessageType.acknowledgement;
      default:
        throw FormatException('Unsupported Offlink message type: $value');
    }
  }
}
