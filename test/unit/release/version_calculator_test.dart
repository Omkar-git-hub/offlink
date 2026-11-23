import 'package:flutter_test/flutter_test.dart';
import '../../../tool/release/version_calculator.dart';

void main() {
  group('SemanticVersion Parser', () {
    test('parses simple semver tag', () {
      final v = SemanticVersion.parse('v1.2.3');
      expect(v, isNotNull);
      expect(v!.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
      expect(v.preReleaseChannel, isNull);
      expect(v.preReleaseIteration, isNull);
      expect(v.versionName, '1.2.3');
      expect(v.tagName, 'v1.2.3');
      expect(v.isPreRelease, isFalse);
    });

    test('parses alpha pre-release tag', () {
      final v = SemanticVersion.parse('v0.1.0-alpha.1');
      expect(v, isNotNull);
      expect(v!.major, 0);
      expect(v.minor, 1);
      expect(v.patch, 0);
      expect(v.preReleaseChannel, 'alpha');
      expect(v.preReleaseIteration, 1);
      expect(v.versionName, '0.1.0-alpha.1');
      expect(v.tagName, 'v0.1.0-alpha.1');
      expect(v.isPreRelease, isTrue);
    });

    test('parses version with build number', () {
      final v = SemanticVersion.parse('0.2.0-beta.2+42');
      expect(v, isNotNull);
      expect(v!.major, 0);
      expect(v.minor, 2);
      expect(v.patch, 0);
      expect(v.preReleaseChannel, 'beta');
      expect(v.preReleaseIteration, 2);
      expect(v.versionCode, 42);
    });

    test('returns null for invalid string', () {
      expect(SemanticVersion.parse('invalid-version'), isNull);
    });
  });

  group('SemanticVersion Next Version Calculator', () {
    final currentAlpha = SemanticVersion.parse(
      'v0.1.0-alpha.1',
      versionCode: 1,
    )!;

    test('defaults to bumping alpha iteration when no label is provided', () {
      final next = SemanticVersion.calculateNext(currentVersion: currentAlpha);
      expect(next.versionName, '0.1.0-alpha.2');
      expect(next.tagName, 'v0.1.0-alpha.2');
      expect(next.versionCode, 2);
      expect(next.isPreRelease, isTrue);
    });

    test('handles release:minor label on pre-release', () {
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        labels: ['release:minor'],
      );
      expect(next.versionName, '0.2.0-alpha.1');
      expect(next.versionCode, 2);
    });

    test('handles release:major label on pre-release', () {
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        labels: ['release:major'],
      );
      expect(next.versionName, '1.0.0-alpha.1');
      expect(next.versionCode, 2);
    });

    test('handles release:patch label on pre-release', () {
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        labels: ['release:patch'],
      );
      expect(next.versionName, '0.1.1-alpha.1');
      expect(next.versionCode, 2);
    });

    test('handles release:beta transition', () {
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        labels: ['release:beta'],
      );
      expect(next.versionName, '0.1.0-beta.1');
      expect(next.versionCode, 2);
    });

    test('promotes pre-release to stable with release:stable', () {
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        labels: ['release:stable'],
      );
      expect(next.versionName, '0.1.0');
      expect(next.tagName, 'v0.1.0');
      expect(next.isPreRelease, isFalse);
    });

    test('promotes to stable with minor bump', () {
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        labels: ['release:minor', 'release:stable'],
      );
      expect(next.versionName, '0.2.0');
      expect(next.isPreRelease, isFalse);
    });

    test('bumps patch by default on stable version', () {
      final currentStable = SemanticVersion.parse('v1.0.0', versionCode: 10)!;
      final next = SemanticVersion.calculateNext(currentVersion: currentStable);
      expect(next.versionName, '1.0.1');
      expect(next.versionCode, 11);
      expect(next.isPreRelease, isFalse);
    });

    test('avoids collision with existing git tags', () {
      final existing = ['v0.1.0-alpha.1', 'v0.1.0-alpha.2'];
      final next = SemanticVersion.calculateNext(
        currentVersion: currentAlpha,
        existingTags: existing,
      );
      expect(next.versionName, '0.1.0-alpha.3');
      expect(next.tagName, 'v0.1.0-alpha.3');
    });

    test('detects release skipping via labels and commit message', () {
      expect(SemanticVersion.isReleaseSkipped(['release:skip']), isTrue);
      expect(SemanticVersion.isReleaseSkipped(['no-release']), isTrue);
      expect(SemanticVersion.isReleaseSkipped(['skip-release']), isTrue);
      expect(
        SemanticVersion.isReleaseSkipped(
          [],
          commitMessage: 'chore: update docs [skip release]',
        ),
        isTrue,
      );
      expect(
        SemanticVersion.isReleaseSkipped(
          [],
          commitMessage: 'fix: internal refactor [no release]',
        ),
        isTrue,
      );
      expect(SemanticVersion.isReleaseSkipped(['release:patch']), isFalse);
      expect(
        SemanticVersion.isReleaseSkipped([
          'release:minor',
        ], commitMessage: 'feat: new feature'),
        isFalse,
      );
    });
  });
}
