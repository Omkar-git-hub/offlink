import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/release/release_notes_generator.dart';

void main() {
  group('ReleaseNotesGenerator Categorization', () {
    test('categorizes commits into correct functional areas', () {
      final sampleCommits = [
        'feat(ble): add GATT connection pooling|a1b2c3d|developer',
        'security(crypto): enforce key mismatch detection|b2c3d4e|security_lead',
        'perf(battery): eliminate idle periodic timer|c3d4e5f|engineer',
        'fix(mesh): handle packet deduplication overflow|d4e5f6a|tester',
        'docs: update android installation guide|e5f6a7b|writer',
        'ci: add automated PR validation workflow|f6a7b8c|devops',
        'random refactor of helper method|0a1b2c3|developer',
      ];

      final categorized = ReleaseNotesGenerator.categorizeCommits(
        sampleCommits,
      );

      expect(categorized['🚀 Features & Enhancements']!.length, 1);
      expect(
        categorized['🚀 Features & Enhancements']!.first,
        contains('feat(ble)'),
      );

      expect(categorized['🔒 Security Hardening']!.length, 1);
      expect(
        categorized['🔒 Security Hardening']!.first,
        contains('security(crypto)'),
      );

      expect(categorized['⚡ Battery & Performance']!.length, 1);
      expect(
        categorized['⚡ Battery & Performance']!.first,
        contains('perf(battery)'),
      );

      expect(categorized['🐛 Fixes & Resilience']!.length, 1);
      expect(
        categorized['🐛 Fixes & Resilience']!.first,
        contains('fix(mesh)'),
      );

      expect(categorized['📚 Documentation']!.length, 1);
      expect(categorized['📚 Documentation']!.first, contains('docs'));

      expect(categorized['🔧 Tooling & CI/CD']!.length, 1);
      expect(categorized['🔧 Tooling & CI/CD']!.first, contains('ci'));

      expect(categorized['📦 Other Changes']!.length, 1);
      expect(
        categorized['📦 Other Changes']!.first,
        contains('random refactor'),
      );
    });

    test('ignores merge pull request headers', () {
      final commits = [
        'Merge pull request #22 from Omkar-git-hub/feature/security|1234567|Omkar',
        'Merge branch main into feature/xyz|2345678|Omkar',
        'feat: add offline queue recovery|3456789|Omkar',
      ];

      final categorized = ReleaseNotesGenerator.categorizeCommits(commits);
      expect(categorized['🚀 Features & Enhancements']!.length, 1);
      expect(categorized['📦 Other Changes']!.length, 0);
    });
  });

  group('ReleaseNotesGenerator buildNotes', () {
    test('produces formatted markdown with metadata and categories', () {
      final categorized = {
        '🚀 Features & Enhancements': ['feat(mesh): multi-hop relay'],
        '🔒 Security Hardening': ['security: 60-digit safety fingerprint'],
      };

      final markdown = ReleaseNotesGenerator.buildNotes(
        version: '0.1.0-alpha.2',
        channel: 'alpha',
        isPreRelease: true,
        categorized: categorized,
        releaseDate: '2026-11-24',
      );

      expect(markdown, contains('# Offlink v0.1.0-alpha.2'));
      expect(
        markdown,
        contains('**Release Classification**: Developer Alpha (Pre-Release)'),
      );
      expect(markdown, contains('**Release Date**: 2026-11-24'));
      expect(markdown, contains('### 🚀 Features & Enhancements'));
      expect(markdown, contains('- feat(mesh): multi-hop relay'));
      expect(markdown, contains('### 🔒 Security Hardening'));
      expect(markdown, contains('- security: 60-digit safety fingerprint'));
      expect(markdown, contains('## Verification & Security'));
    });
  });

  group('ReleaseNotesGenerator changelog update', () {
    test('prepends new release section to changelog file', () {
      final tempDir = Directory.systemTemp.createTempSync('changelog_test');
      final changelog = File('${tempDir.path}/CHANGELOG.md');
      changelog.writeAsStringSync(
        '# Changelog\n\n## [0.1.0-alpha.1] - 2026-11-23\n- Initial release\n',
      );

      final categorized = {
        '🚀 Features & Enhancements': ['feat: new capability'],
      };

      ReleaseNotesGenerator.prependToChangelog(
        changelogFile: changelog,
        version: '0.1.0-alpha.2',
        categorized: categorized,
        releaseDate: '2026-11-24',
      );

      final content = changelog.readAsStringSync();
      expect(content, contains('## [0.1.0-alpha.2] - 2026-11-24'));
      expect(content, contains('### 🚀 Features & Enhancements'));
      expect(content, contains('- feat: new capability'));
      expect(content, contains('## [0.1.0-alpha.1] - 2026-11-23'));

      tempDir.deleteSync(recursive: true);
    });
  });
}
