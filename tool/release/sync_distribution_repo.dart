import 'dart:convert';
import 'dart:io';

/// Synchronizes release metadata, CHANGELOG.md, and RELEASES.md in the official
/// distribution repository (Omkar-git-hub/offlink-releases).
class DistributionRepoSynchronizer {
  final Directory distributionDir;

  DistributionRepoSynchronizer({required this.distributionDir});

  File get releaseInfoFile =>
      File('${distributionDir.path}/metadata/release-information.json');
  File get appInfoFile =>
      File('${distributionDir.path}/metadata/app-information.json');
  File get changelogFile => File('${distributionDir.path}/CHANGELOG.md');
  File get releasesDocFile => File('${distributionDir.path}/RELEASES.md');

  /// Updates metadata/release-information.json.
  void updateReleaseInformation({
    required String version,
    required int versionCode,
    required String tag,
    required String releaseDate,
    required String channel,
    required bool preRelease,
    required String apkFileName,
    required int fileSize,
    required String sha256,
    String? signingType,
    String? signingCertSha256,
  }) {
    final metaDir = Directory('${distributionDir.path}/metadata');
    if (!metaDir.existsSync()) {
      metaDir.createSync(recursive: true);
    }

    Map<String, dynamic> current = {};
    if (releaseInfoFile.existsSync()) {
      try {
        current =
            jsonDecode(releaseInfoFile.readAsStringSync())
                as Map<String, dynamic>;
      } catch (_) {
        current = {};
      }
    }

    final signingCert = <String, dynamic>{
      'type': signingType ?? 'Android Keystore',
      'signatureScheme': 'v2',
    };
    if (signingCertSha256 != null && signingCertSha256.isNotEmpty) {
      signingCert['sha256'] = signingCertSha256;
    } else if (current['latestRelease']?['signingCertificate']?['sha256'] !=
        null) {
      signingCert['sha256'] =
          current['latestRelease']['signingCertificate']['sha256'];
    }

    current['latestRelease'] = {
      'version': version,
      'versionCode': versionCode,
      'tag': tag,
      'releaseDate': releaseDate,
      'channel': channel,
      'preRelease': preRelease,
      'apkFileName': apkFileName,
      'fileSize': fileSize,
      'sha256': sha256,
      'downloadUrl':
          'https://github.com/Omkar-git-hub/offlink-releases/releases/download/$tag/$apkFileName',
      'signingCertificate': signingCert,
    };

    const encoder = JsonEncoder.withIndent('  ');
    releaseInfoFile.writeAsStringSync('${encoder.convert(current)}\n');
  }

  /// Updates metadata/app-information.json ensuring correct production identity.
  void updateAppInformation({
    String applicationId = 'io.github.omkar_git_hub.offlink',
  }) {
    if (!appInfoFile.existsSync()) return;

    try {
      final current =
          jsonDecode(appInfoFile.readAsStringSync()) as Map<String, dynamic>;
      current['applicationId'] = applicationId;
      const encoder = JsonEncoder.withIndent('  ');
      appInfoFile.writeAsStringSync('${encoder.convert(current)}\n');
    } catch (e) {
      stderr.writeln('Warning: Failed to update app-information.json: $e');
    }
  }

  /// Prepends release notes to CHANGELOG.md under the header.
  void updateChangelog({required String releaseNotes}) {
    if (!changelogFile.existsSync()) {
      changelogFile.writeAsStringSync('# Changelog\n\n$releaseNotes\n');
      return;
    }

    final content = changelogFile.readAsStringSync();
    // Check if this version entry already exists
    final lines = releaseNotes.trim().split('\n');
    final firstHeader = lines.isNotEmpty ? lines.first.trim() : '';
    if (firstHeader.isNotEmpty && content.contains(firstHeader)) {
      // Entry already present
      return;
    }

    // Insert after standard keep-a-changelog header
    final headerDivider = '---';
    final dividerIndex = content.indexOf(headerDivider);
    if (dividerIndex != -1) {
      final insertionPoint = dividerIndex + headerDivider.length;
      final before = content.substring(0, insertionPoint);
      final after = content.substring(insertionPoint);
      changelogFile.writeAsStringSync('$before\n\n$releaseNotes$after');
    } else {
      changelogFile.writeAsStringSync(
        '# Changelog\n\n$releaseNotes\n\n$content',
      );
    }
  }

  /// Adds a new release entry row into RELEASES.md table.
  void updateReleasesDoc({
    required String version,
    required String tag,
    required String releaseDate,
    required String channel,
    required String sha256,
  }) {
    if (!releasesDocFile.existsSync()) return;

    final content = releasesDocFile.readAsStringSync();
    if (content.contains('**$tag**') || content.contains('**v$version**')) {
      // Already recorded
      return;
    }

    final tableDivider =
        '| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |';
    final dividerIndex = content.indexOf(tableDivider);
    if (dividerIndex == -1) return;

    final insertionPoint = dividerIndex + tableDivider.length;
    final before = content.substring(0, insertionPoint);
    final after = content.substring(insertionPoint);

    final displayChannel = channel.isNotEmpty
        ? '${channel[0].toUpperCase()}${channel.substring(1)}'
        : 'Release';
    final shortSha = sha256.length > 12
        ? '${sha256.substring(0, 12)}...'
        : sha256;
    final notesAnchor = 'CHANGELOG.md#${version.replaceAll('.', '')}';

    final newRow =
        '\n| **v$version** | $releaseDate | $displayChannel | [`$tag`](https://github.com/Omkar-git-hub/offlink-releases/releases/tag/$tag) | API 36 | API 24 | `$shortSha` | [Notes]($notesAnchor) |';

    releasesDocFile.writeAsStringSync('$before$newRow$after');
  }
}

/// CLI entrypoint.
void main(List<String> args) {
  String? distributionDirPath;
  String? version;
  int versionCode = 1;
  String? tag;
  String? apkPath;
  String? sha256;
  String? checksumFilePath;
  String? notesPath;
  String channel = 'alpha';
  bool preRelease = true;
  String releaseDate = DateTime.now().toUtc().toIso8601String().substring(
    0,
    10,
  );
  String? signingType;
  String? signingCertSha256;

  for (final arg in args) {
    if (arg.startsWith('--distribution-dir=')) {
      distributionDirPath = arg.substring('--distribution-dir='.length);
    } else if (arg.startsWith('--version=')) {
      version = arg.substring('--version='.length);
    } else if (arg.startsWith('--version-code=')) {
      versionCode = int.tryParse(arg.substring('--version-code='.length)) ?? 1;
    } else if (arg.startsWith('--tag=')) {
      tag = arg.substring('--tag='.length);
    } else if (arg.startsWith('--apk=')) {
      apkPath = arg.substring('--apk='.length);
    } else if (arg.startsWith('--sha256=')) {
      sha256 = arg.substring('--sha256='.length).trim();
    } else if (arg.startsWith('--checksum-file=')) {
      checksumFilePath = arg.substring('--checksum-file='.length);
    } else if (arg.startsWith('--notes=')) {
      notesPath = arg.substring('--notes='.length);
    } else if (arg.startsWith('--channel=')) {
      channel = arg.substring('--channel='.length);
    } else if (arg.startsWith('--prerelease=')) {
      preRelease =
          arg.substring('--prerelease='.length).toLowerCase() == 'true';
    } else if (arg.startsWith('--release-date=')) {
      releaseDate = arg.substring('--release-date='.length);
    } else if (arg.startsWith('--signing-type=')) {
      signingType = arg.substring('--signing-type='.length);
    } else if (arg.startsWith('--signing-cert-sha256=')) {
      signingCertSha256 = arg.substring('--signing-cert-sha256='.length);
    }
  }

  if (distributionDirPath == null || version == null) {
    stderr.writeln(
      'Usage: dart run tool/release/sync_distribution_repo.dart --distribution-dir=<path> --version=<version> [options]',
    );
    exit(1);
  }

  final dir = Directory(distributionDirPath);
  if (!dir.existsSync()) {
    stderr.writeln(
      'Error: Distribution directory not found at $distributionDirPath',
    );
    exit(1);
  }

  tag ??= 'v$version';

  final apkFile = apkPath != null ? File(apkPath) : null;
  final apkFileName = apkFile != null
      ? apkFile.uri.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => 'Offlink-$version.apk',
        )
      : 'Offlink-$version.apk';
  final fileSize = apkFile != null && apkFile.existsSync()
      ? apkFile.lengthSync()
      : 0;

  if (sha256 == null || sha256.isEmpty) {
    if (checksumFilePath != null && File(checksumFilePath).existsSync()) {
      final line = File(checksumFilePath).readAsStringSync().trim();
      final parts = line.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) sha256 = parts.first;
    }
  }
  sha256 ??= '';

  String releaseNotes =
      '## [$version] - $releaseDate\n\nRelease notes for v$version.\n';
  if (notesPath != null && File(notesPath).existsSync()) {
    releaseNotes = File(notesPath).readAsStringSync();
  }

  final syncer = DistributionRepoSynchronizer(distributionDir: dir);

  stdout.writeln('Synchronizing distribution repository at ${dir.path}...');
  syncer.updateReleaseInformation(
    version: version,
    versionCode: versionCode,
    tag: tag,
    releaseDate: releaseDate,
    channel: channel,
    preRelease: preRelease,
    apkFileName: apkFileName,
    fileSize: fileSize,
    sha256: sha256,
    signingType: signingType,
    signingCertSha256: signingCertSha256,
  );
  stdout.writeln('Updated metadata/release-information.json');

  syncer.updateAppInformation();
  stdout.writeln('Verified metadata/app-information.json');

  syncer.updateChangelog(releaseNotes: releaseNotes);
  stdout.writeln('Updated CHANGELOG.md');

  syncer.updateReleasesDoc(
    version: version,
    tag: tag,
    releaseDate: releaseDate,
    channel: channel,
    sha256: sha256,
  );
  stdout.writeln('Updated RELEASES.md');

  stdout.writeln('Distribution repository synchronization complete.');
}
