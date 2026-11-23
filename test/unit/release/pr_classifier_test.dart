import 'package:flutter_test/flutter_test.dart';
import '../../../tool/release/pr_classifier.dart';

void main() {
  group('PrClassifier Parsing & Release Rules', () {
    test('classifies feat as standard release', () {
      final p = PrClassifier.parse('feat: add mesh routing');
      expect(p, isNotNull);
      expect(p!.type, 'feat');
      expect(p.scope, isNull);
      expect(p.isBreaking, isFalse);
      expect(p.action, ReleaseAction.release);
      expect(p.shouldRelease, isTrue);
    });

    test('classifies scoped feat as standard release', () {
      final p = PrClassifier.parse('feat(ble): add adaptive scan rate');
      expect(p, isNotNull);
      expect(p!.type, 'feat');
      expect(p.scope, 'ble');
      expect(p.isBreaking, isFalse);
      expect(p.action, ReleaseAction.release);
      expect(p.shouldRelease, isTrue);
    });

    test('classifies fix as standard release', () {
      final p = PrClassifier.parse('fix: resolve BLE connection failure');
      expect(p, isNotNull);
      expect(p!.type, 'fix');
      expect(p.isBreaking, isFalse);
      expect(p.action, ReleaseAction.release);
      expect(p.shouldRelease, isTrue);
    });

    test('classifies perf as standard release', () {
      final p = PrClassifier.parse('perf(battery): optimize wake locks');
      expect(p, isNotNull);
      expect(p!.type, 'perf');
      expect(p.scope, 'battery');
      expect(p.isBreaking, isFalse);
      expect(p.action, ReleaseAction.release);
      expect(p.shouldRelease, isTrue);
    });

    test('classifies feat! as breaking release', () {
      final p = PrClassifier.parse('feat!: redesign cryptographic handshake');
      expect(p, isNotNull);
      expect(p!.type, 'feat');
      expect(p.isBreaking, isTrue);
      expect(p.action, ReleaseAction.breakingRelease);
      expect(p.shouldRelease, isTrue);
    });

    test('classifies fix(api)! as breaking release', () {
      final p = PrClassifier.parse(
        'fix(api)!: remove deprecated packet format',
      );
      expect(p, isNotNull);
      expect(p!.type, 'fix');
      expect(p.scope, 'api');
      expect(p.isBreaking, isTrue);
      expect(p.action, ReleaseAction.breakingRelease);
      expect(p.shouldRelease, isTrue);
    });

    test('classifies docs as no release', () {
      final p = PrClassifier.parse(
        'docs: update release pipeline documentation',
      );
      expect(p, isNotNull);
      expect(p!.type, 'docs');
      expect(p.action, ReleaseAction.noRelease);
      expect(p.shouldRelease, isFalse);
    });

    test('classifies test as no release', () {
      final p = PrClassifier.parse('test: add unit tests for flood limiter');
      expect(p, isNotNull);
      expect(p!.type, 'test');
      expect(p.action, ReleaseAction.noRelease);
      expect(p.shouldRelease, isFalse);
    });

    test('classifies chore as no release', () {
      final p = PrClassifier.parse('chore(deps): bump package versions');
      expect(p, isNotNull);
      expect(p!.type, 'chore');
      expect(p.action, ReleaseAction.noRelease);
      expect(p.shouldRelease, isFalse);
    });

    test('classifies ci as no release', () {
      final p = PrClassifier.parse('ci: update flutter ci workflow runners');
      expect(p, isNotNull);
      expect(p!.type, 'ci');
      expect(p.action, ReleaseAction.noRelease);
      expect(p.shouldRelease, isFalse);
    });

    test('classifies refactor as no release by default', () {
      final p = PrClassifier.parse('refactor: decouple discovery service');
      expect(p, isNotNull);
      expect(p!.type, 'refactor');
      expect(p.action, ReleaseAction.noRelease);
      expect(p.shouldRelease, isFalse);
    });

    test('classifies refactor with [release] token as release', () {
      final p = PrClassifier.parse(
        'refactor: user-visible dialog layout [release]',
      );
      expect(p, isNotNull);
      expect(p!.type, 'refactor');
      expect(p.action, ReleaseAction.release);
      expect(p.shouldRelease, isTrue);
    });
  });

  group('PrClassifier Validation', () {
    test('validates conformant conventional titles', () {
      expect(PrClassifier.validate('feat: new peer exchange'), isNull);
      expect(
        PrClassifier.validate('fix(ble): resolve gatt race condition'),
        isNull,
      );
      expect(
        PrClassifier.validate('perf(battery)!: change default duty cycle'),
        isNull,
      );
      expect(
        PrClassifier.validate('docs(readme): add build instructions'),
        isNull,
      );
      expect(PrClassifier.validate('chore: update dependencies'), isNull);
    });

    test('rejects empty title with clear error', () {
      final error = PrClassifier.validate('   ');
      expect(error, isNotNull);
      expect(error, contains('must not be empty'));
    });

    test('rejects non-conventional titles with actionable guidance', () {
      final error = PrClassifier.validate('Update the app for next release');
      expect(error, isNotNull);
      expect(
        error,
        contains('Expected format: <type>(<scope>): <description>'),
      );
      expect(error, contains('feat:'));
      expect(error, contains('fix:'));
      expect(error, contains('docs:'));
    });

    test('rejects titles missing colon or space', () {
      expect(PrClassifier.validate('feat new feature'), isNotNull);
      expect(PrClassifier.validate('fix:no space after colon'), isNotNull);
    });
  });
}
