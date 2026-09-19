import 'package:flutter_test/flutter_test.dart';
import 'package:offlink/core/identity/node_id_generator.dart';

void main() {
  group('NodeIdGenerator', () {
    late NodeIdGenerator generator;

    setUp(() {
      generator = NodeIdGenerator();
    });

    test('generates a 32-character hexadecimal node ID', () {
      final nodeId = generator.generate();

      expect(nodeId.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(nodeId), isTrue);
    });

    test('generates different node IDs', () {
      final first = generator.generate();
      final second = generator.generate();

      expect(first, isNot(equals(second)));
    });

    test('generates a new ID on each generation', () {
      final ids = <String>{};

      for (var i = 0; i < 100; i++) {
        ids.add(generator.generate());
      }

      expect(ids.length, 100);
    });
  });
}
