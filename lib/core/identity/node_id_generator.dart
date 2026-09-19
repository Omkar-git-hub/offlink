import 'dart:math';

class NodeIdGenerator {
  NodeIdGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String generate() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
