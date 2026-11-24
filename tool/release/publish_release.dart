import 'dart:io';

class ReleasePublisher {
  const ReleasePublisher();

  /// Executes a shell command and returns output.
  static ProcessResult runCmd(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
  }) {
    return Process.runSync(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
    );
  }

  /// Verifies whether a GitHub Release already exists for a given tag.
  static bool checkReleaseExists(String repo, String tag, {String? token}) {
    final env = token != null
        ? {'GH_TOKEN': token, 'GITHUB_TOKEN': token}
        : null;
    final result = runCmd('gh', [
      'release',
      'view',
      tag,
      '--repo',
      repo,
    ], environment: env);
    return result.exitCode == 0;
  }

  /// Uploads or overwrites assets for an existing release.
  static bool uploadAssets({
    required String repo,
    required String tag,
    required List<File> assets,
    String? token,
  }) {
    final env = token != null
        ? {'GH_TOKEN': token, 'GITHUB_TOKEN': token}
        : null;

    final args = <String>[
      'release',
      'upload',
      tag,
      '--repo',
      repo,
      '--clobber',
    ];

    for (final asset in assets) {
      if (asset.existsSync()) {
        args.add(asset.path);
      } else {
        stderr.writeln('Warning: Asset ${asset.path} does not exist, skipping');
      }
    }

    final result = runCmd('gh', args, environment: env);
    if (result.exitCode != 0) {
      stderr.writeln('Failed to upload assets on $repo: ${result.stderr}');
      return false;
    }

    stdout.writeln('Successfully uploaded assets for $tag on $repo');
    stdout.writeln(result.stdout);
    return true;
  }

  /// Creates a GitHub release and uploads assets.
  static bool createRelease({
    required String repo,
    required String tag,
    required String title,
    required File notesFile,
    required List<File> assets,
    required bool isPreRelease,
    bool makeLatest = false,
    String? targetCommitish,
    String? token,
  }) {
    final env = token != null
        ? {'GH_TOKEN': token, 'GITHUB_TOKEN': token}
        : null;

    final args = <String>[
      'release',
      'create',
      tag,
      '--repo',
      repo,
      '--title',
      title,
      '--notes-file',
      notesFile.path,
    ];

    if (isPreRelease) {
      args.add('--prerelease');
    } else if (makeLatest) {
      args.add('--latest');
    }

    if (targetCommitish != null && targetCommitish.isNotEmpty) {
      args.addAll(['--target', targetCommitish]);
    }

    for (final asset in assets) {
      if (asset.existsSync()) {
        args.add(asset.path);
      } else {
        stderr.writeln('Warning: Asset ${asset.path} does not exist, skipping');
      }
    }

    final result = runCmd('gh', args, environment: env);
    if (result.exitCode != 0) {
      stderr.writeln('Failed to create release on $repo: ${result.stderr}');
      return false;
    }

    stdout.writeln('Successfully published release $tag on $repo');
    stdout.writeln(result.stdout);
    return true;
  }

  /// Sets an existing release as latest and ensures it is published as standard release.
  static bool setLatest({
    required String repo,
    required String tag,
    String? token,
  }) {
    final env = token != null
        ? {'GH_TOKEN': token, 'GITHUB_TOKEN': token}
        : null;
    final result = runCmd('gh', [
      'release',
      'edit',
      tag,
      '--repo',
      repo,
      '--latest',
      '--prerelease=false',
    ], environment: env);
    if (result.exitCode != 0) {
      stderr.writeln(
        'Warning: Failed to set $tag as latest on $repo: ${result.stderr}',
      );
      return false;
    }
    stdout.writeln('Successfully marked $tag as latest release on $repo');
    return true;
  }
}

/// CLI entrypoint.
void main(List<String> args) {
  String? apkPath;
  String? stableApkPath;
  String? checksumPath;
  String? notesPath;
  String? version;
  String? tag;
  bool isPreRelease = true;
  bool distributionMode = false;
  String distributionRepo = 'Omkar-git-hub/offlink-releases';
  String sourceRepo = 'Omkar-git-hub/offlink';
  String? token =
      Platform.environment['RELEASE_TOKEN'] ??
      Platform.environment['GH_TOKEN'] ??
      Platform.environment['GITHUB_TOKEN'];
  String? targetCommitish;
  bool dryRun = false;

  for (final arg in args) {
    if (arg.startsWith('--apk=')) {
      apkPath = arg.substring('--apk='.length);
    } else if (arg.startsWith('--stable-apk=')) {
      stableApkPath = arg.substring('--stable-apk='.length);
    } else if (arg == '--distribution-mode') {
      distributionMode = true;
    } else if (arg.startsWith('--checksum=')) {
      checksumPath = arg.substring('--checksum='.length);
    } else if (arg.startsWith('--notes=')) {
      notesPath = arg.substring('--notes='.length);
    } else if (arg.startsWith('--version=')) {
      version = arg.substring('--version='.length);
    } else if (arg.startsWith('--tag=')) {
      tag = arg.substring('--tag='.length);
    } else if (arg.startsWith('--target=') ||
        arg.startsWith('--target-commitish=')) {
      targetCommitish = arg.split('=').sublist(1).join('=');
    } else if (arg.startsWith('--prerelease=')) {
      isPreRelease =
          arg.substring('--prerelease='.length).toLowerCase() == 'true';
    } else if (arg.startsWith('--distribution-repo=')) {
      distributionRepo = arg.substring('--distribution-repo='.length);
    } else if (arg.startsWith('--source-repo=')) {
      sourceRepo = arg.substring('--source-repo='.length);
    } else if (arg.startsWith('--token=')) {
      token = arg.substring('--token='.length);
    } else if (arg == '--dry-run') {
      dryRun = true;
    }
  }

  if (distributionMode) {
    isPreRelease = false;
  }

  if (version == null || version.isEmpty) {
    stderr.writeln('Error: --version is required');
    exit(1);
  }

  tag ??= 'v$version';

  final notesFile = notesPath != null ? File(notesPath) : null;
  if (notesFile == null || !notesFile.existsSync()) {
    stderr.writeln('Error: Release notes file does not exist at $notesPath');
    exit(1);
  }

  final assets = <File>[];
  if (apkPath != null && apkPath.isNotEmpty) {
    final apkFile = File(apkPath);
    if (apkFile.existsSync()) {
      assets.add(apkFile);
    } else {
      stderr.writeln('Error: APK file does not exist at $apkPath');
      exit(1);
    }
  }

  if (stableApkPath != null && stableApkPath.isNotEmpty) {
    final stableApk = File(stableApkPath);
    if (stableApk.existsSync()) {
      assets.add(stableApk);
    } else {
      stderr.writeln('Error: Stable APK file does not exist at $stableApkPath');
      exit(1);
    }
  }

  if (checksumPath != null && checksumPath.isNotEmpty) {
    final checksumFile = File(checksumPath);
    if (checksumFile.existsSync()) {
      assets.add(checksumFile);
    } else {
      stderr.writeln('Error: Checksum file does not exist at $checksumPath');
      exit(1);
    }
  }

  stdout.writeln('Preparing to publish release:');
  stdout.writeln('Source Repository: $sourceRepo');
  stdout.writeln('Target Repository: $distributionRepo');
  stdout.writeln('Tag              : $tag');
  stdout.writeln('Title            : Offlink v$version');
  stdout.writeln('Pre-Release      : $isPreRelease');
  stdout.writeln('Distribution Mode: $distributionMode');
  stdout.writeln(
    'Assets (${assets.length}): ${assets.map((a) => a.path).join(", ")}',
  );

  if (dryRun) {
    stdout.writeln(
      'Dry-run completed successfully. No remote releases created.',
    );
    exit(0);
  }

  final title = 'Offlink v$version';

  // Check if release exists on distribution repo
  final exists = ReleasePublisher.checkReleaseExists(
    distributionRepo,
    tag,
    token: token,
  );
  if (exists) {
    stdout.writeln(
      'Release $tag already exists on $distributionRepo. Reconciling assets...',
    );
    final uploaded = ReleasePublisher.uploadAssets(
      repo: distributionRepo,
      tag: tag,
      assets: assets,
      token: token,
    );
    if (!uploaded) {
      stderr.writeln(
        'Error: Failed to reconcile some assets on $distributionRepo',
      );
      exit(1);
    }
    if (distributionMode) {
      ReleasePublisher.setLatest(
        repo: distributionRepo,
        tag: tag,
        token: token,
      );
    }
    stdout.writeln('Release asset reconciliation completed.');
    exit(0);
  }

  // Publish to distribution repository
  final success = ReleasePublisher.createRelease(
    repo: distributionRepo,
    tag: tag,
    title: title,
    notesFile: notesFile,
    assets: assets,
    isPreRelease: isPreRelease,
    makeLatest: distributionMode || !isPreRelease,
    targetCommitish: targetCommitish,
    token: token,
  );

  if (!success) {
    stderr.writeln('Failed to publish release to $distributionRepo');
    exit(1);
  }

  stdout.writeln('Release publication completed successfully.');
}
