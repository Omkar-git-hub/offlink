import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Since tool/release/sync_distribution_repo.dart is outside lib/, we can import it relative or test its logic directly
import '../../../tool/release/sync_distribution_repo.dart';

void main() {
  group('DistributionRepoSynchronizer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dist_sync_test_');
      // Create skeleton files
      Directory('${tempDir.path}/metadata').createSync(recursive: true);
      File(
        '${tempDir.path}/metadata/release-information.json',
      ).writeAsStringSync('{}');
      File('${tempDir.path}/metadata/app-information.json').writeAsStringSync(
        jsonEncode({'applicationId': 'com.old.id', 'name': 'Offlink'}),
      );
      File('${tempDir.path}/CHANGELOG.md').writeAsStringSync(
        '# Changelog\n\nSome intro text.\n\n---\n\n## [0.1.0-alpha.1] - 2026-11-23\nInitial release.\n',
      );
      File('${tempDir.path}/RELEASES.md').writeAsStringSync(
        '# Releases\n\n| Version | Release Date | Channel | Git Tag | Target SDK | Min SDK | SHA-256 Checksum | Release Notes |\n| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n| **v0.1.0-alpha.1** | 2026-11-23 | Alpha | [`v0.1.0-alpha.1`](https://example.com) | API 36 | API 24 | `123456789012...` | [Notes](CHANGELOG.md) |\n',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('updates release-information.json correctly', () {
      final syncer = DistributionRepoSynchronizer(distributionDir: tempDir);
      syncer.updateReleaseInformation(
        version: '0.1.0-alpha.2',
        versionCode: 2,
        tag: 'v0.1.0-alpha.2',
        releaseDate: '2026-11-24',
        channel: 'alpha',
        preRelease: true,
        apkFileName: 'Offlink-0.1.0-alpha.2.apk',
        fileSize: 45000000,
        sha256:
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        signingType: 'Android Release Keystore',
        signingCertSha256: 'certsha256value',
      );

      final file = File('${tempDir.path}/metadata/release-information.json');
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['latestRelease']['version'], equals('0.1.0-alpha.2'));
      expect(json['latestRelease']['versionCode'], equals(2));
      expect(json['latestRelease']['tag'], equals('v0.1.0-alpha.2'));
      expect(json['latestRelease']['preRelease'], isTrue);
      expect(json['latestRelease']['fileSize'], equals(45000000));
      expect(
        json['latestRelease']['signingCertificate']['type'],
        equals('Android Release Keystore'),
      );
      expect(
        json['latestRelease']['signingCertificate']['sha256'],
        equals('certsha256value'),
      );
    });

    test('updates app-information.json with production applicationId', () {
      final syncer = DistributionRepoSynchronizer(distributionDir: tempDir);
      syncer.updateAppInformation();

      final file = File('${tempDir.path}/metadata/app-information.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['applicationId'], equals('io.github.omkar_git_hub.offlink'));
      expect(json['name'], equals('Offlink'));
    });

    test('updates CHANGELOG.md by prepending release notes', () {
      final syncer = DistributionRepoSynchronizer(distributionDir: tempDir);
      final newNotes =
          '## [0.1.0-alpha.2] - 2026-11-24\n\n### Added\n- New feature.\n';
      syncer.updateChangelog(releaseNotes: newNotes);

      final file = File('${tempDir.path}/CHANGELOG.md');
      final content = file.readAsStringSync();
      expect(content.contains('## [0.1.0-alpha.2] - 2026-11-24'), isTrue);
      expect(content.contains('## [0.1.0-alpha.1] - 2026-11-23'), isTrue);
      // New notes should appear before old notes
      expect(
        content.indexOf('0.1.0-alpha.2') < content.indexOf('0.1.0-alpha.1'),
        isTrue,
      );
    });

    test('does not duplicate CHANGELOG.md entry if already present', () {
      final syncer = DistributionRepoSynchronizer(distributionDir: tempDir);
      final newNotes =
          '## [0.1.0-alpha.2] - 2026-11-24\n\n### Added\n- New feature.\n';
      syncer.updateChangelog(releaseNotes: newNotes);
      syncer.updateChangelog(releaseNotes: newNotes);

      final file = File('${tempDir.path}/CHANGELOG.md');
      final occurrences = '## [0.1.0-alpha.2] - 2026-11-24'
          .allMatches(file.readAsStringSync())
          .length;
      expect(occurrences, equals(1));
    });

    test('updates RELEASES.md table with new row', () {
      final syncer = DistributionRepoSynchronizer(distributionDir: tempDir);
      syncer.updateReleasesDoc(
        version: '0.1.0-alpha.2',
        tag: 'v0.1.0-alpha.2',
        releaseDate: '2026-11-24',
        channel: 'alpha',
        sha256:
            'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      );

      final file = File('${tempDir.path}/RELEASES.md');
      final content = file.readAsStringSync();
      expect(content.contains('**v0.1.0-alpha.2**'), isTrue);
      expect(content.contains('[`v0.1.0-alpha.2`]'), isTrue);
      expect(content.contains('`abcdef123456...`'), isTrue);
    });
  });
}
