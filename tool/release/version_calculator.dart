import 'dart:io';

/// Represents a parsed Semantic Version with pre-release channel support.
class SemanticVersion {
  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preReleaseChannel,
    this.preReleaseIteration,
    required this.versionCode,
  });

  final int major;
  final int minor;
  final int patch;
  final String? preReleaseChannel;
  final int? preReleaseIteration;
  final int versionCode;

  bool get isPreRelease => preReleaseChannel != null;

  String get versionName {
    if (preReleaseChannel != null && preReleaseIteration != null) {
      return '$major.$minor.$patch-$preReleaseChannel.$preReleaseIteration';
    } else if (preReleaseChannel != null) {
      return '$major.$minor.$patch-$preReleaseChannel';
    }
    return '$major.$minor.$patch';
  }

  String get tagName => 'v$versionName';

  @override
  String toString() => versionName;

  /// Parses a version string or git tag into [SemanticVersion].
  static SemanticVersion? parse(String raw, {int versionCode = 1}) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^v'), '');
    final match = RegExp(
      r'^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z]+)(?:\.(\d+))?)?(?:\+(\d+))?$',
    ).firstMatch(cleaned);

    if (match == null) return null;

    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    final patch = int.parse(match.group(3)!);
    final channel = match.group(4);
    final iteration = match.group(5) != null
        ? int.parse(match.group(5)!)
        : (channel != null ? 1 : null);
    final parsedBuildCode = match.group(6) != null
        ? int.parse(match.group(6)!)
        : versionCode;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preReleaseChannel: channel,
      preReleaseIteration: iteration,
      versionCode: parsedBuildCode,
    );
  }

  /// Calculates the next [SemanticVersion] based on PR labels and existing tags.
  static SemanticVersion calculateNext({
    SemanticVersion? currentVersion,
    List<String> labels = const [],
    List<String> existingTags = const [],
  }) {
    final current =
        currentVersion ??
        const SemanticVersion(
          major: 0,
          minor: 1,
          patch: 0,
          preReleaseChannel: 'alpha',
          preReleaseIteration: 1,
          versionCode: 1,
        );

    int nextMajor = current.major;
    int nextMinor = current.minor;
    int nextPatch = current.patch;
    String? nextChannel = current.preReleaseChannel;
    int? nextIteration = current.preReleaseIteration;
    final nextVersionCode = current.versionCode + 1;

    final normalizedLabels = labels.map((l) => l.toLowerCase().trim()).toSet();

    if (normalizedLabels.contains('release:major')) {
      nextMajor = current.major + 1;
      nextMinor = 0;
      nextPatch = 0;
      if (normalizedLabels.contains('release:stable')) {
        nextChannel = null;
        nextIteration = null;
      } else if (current.isPreRelease) {
        nextIteration = 1;
      }
    } else if (normalizedLabels.contains('release:minor')) {
      nextMinor = current.minor + 1;
      nextPatch = 0;
      if (normalizedLabels.contains('release:stable')) {
        nextChannel = null;
        nextIteration = null;
      } else if (current.isPreRelease) {
        nextIteration = 1;
      }
    } else if (normalizedLabels.contains('release:patch')) {
      nextPatch = current.patch + 1;
      if (normalizedLabels.contains('release:stable')) {
        nextChannel = null;
        nextIteration = null;
      } else if (current.isPreRelease) {
        nextIteration = 1;
      }
    } else if (normalizedLabels.contains('release:stable')) {
      // Promoting pre-release to stable without bumping major/minor/patch
      nextChannel = null;
      nextIteration = null;
    } else if (normalizedLabels.contains('release:beta')) {
      nextChannel = 'beta';
      nextIteration = (current.preReleaseChannel == 'beta')
          ? (current.preReleaseIteration ?? 0) + 1
          : 1;
    } else if (normalizedLabels.contains('release:alpha')) {
      nextChannel = 'alpha';
      nextIteration = (current.preReleaseChannel == 'alpha')
          ? (current.preReleaseIteration ?? 0) + 1
          : 1;
    } else {
      // Default behavior when no specific release label is present:
      if (current.isPreRelease) {
        nextIteration = (current.preReleaseIteration ?? 0) + 1;
      } else {
        nextPatch = current.patch + 1;
      }
    }

    var candidate = SemanticVersion(
      major: nextMajor,
      minor: nextMinor,
      patch: nextPatch,
      preReleaseChannel: nextChannel,
      preReleaseIteration: nextIteration,
      versionCode: nextVersionCode,
    );

    // Collision avoidance: Ensure tag does not already exist
    final tagsSet = existingTags.toSet();
    while (tagsSet.contains(candidate.tagName)) {
      if (candidate.isPreRelease) {
        candidate = SemanticVersion(
          major: candidate.major,
          minor: candidate.minor,
          patch: candidate.patch,
          preReleaseChannel: candidate.preReleaseChannel,
          preReleaseIteration: (candidate.preReleaseIteration ?? 0) + 1,
          versionCode: candidate.versionCode + 1,
        );
      } else {
        candidate = SemanticVersion(
          major: candidate.major,
          minor: candidate.minor,
          patch: candidate.patch + 1,
          versionCode: candidate.versionCode + 1,
        );
      }
    }

    return candidate;
  }
}

/// CLI entrypoint for release automation.
void main(List<String> args) {
  List<String> labels = [];
  String? githubOutputFile = Platform.environment['GITHUB_OUTPUT'];
  bool updatePubspec = false;

  for (final arg in args) {
    if (arg.startsWith('--labels=')) {
      labels = arg
          .substring('--labels='.length)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (arg.startsWith('--github-output=')) {
      githubOutputFile = arg.substring('--github-output='.length);
    } else if (arg == '--update-pubspec') {
      updatePubspec = true;
    }
  }

  // Also check environment variable for labels
  final envLabels = Platform.environment['PR_LABELS'];
  if (envLabels != null && envLabels.isNotEmpty) {
    labels.addAll(envLabels.split(',').map((s) => s.trim()));
  }

  // Fetch git tags
  final gitResult = Process.runSync('git', ['tag', '-l']);
  final existingTags = (gitResult.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // Find latest tag
  SemanticVersion? latestVersion;
  int highestVersionCode = 0;

  for (final tag in existingTags) {
    final parsed = SemanticVersion.parse(tag);
    if (parsed != null) {
      highestVersionCode++;
      if (latestVersion == null) {
        latestVersion = parsed;
      } else {
        // Compare versions
        if (parsed.major > latestVersion.major ||
            (parsed.major == latestVersion.major &&
                parsed.minor > latestVersion.minor) ||
            (parsed.major == latestVersion.major &&
                parsed.minor == latestVersion.minor &&
                parsed.patch > latestVersion.patch) ||
            (parsed.major == latestVersion.major &&
                parsed.minor == latestVersion.minor &&
                parsed.patch == latestVersion.patch &&
                (parsed.preReleaseIteration ?? 0) >
                    (latestVersion.preReleaseIteration ?? 0))) {
          latestVersion = parsed;
        }
      }
    }
  }

  final current = latestVersion != null
      ? SemanticVersion(
          major: latestVersion.major,
          minor: latestVersion.minor,
          patch: latestVersion.patch,
          preReleaseChannel: latestVersion.preReleaseChannel,
          preReleaseIteration: latestVersion.preReleaseIteration,
          versionCode: highestVersionCode > 0 ? highestVersionCode : 1,
        )
      : null;

  final next = SemanticVersion.calculateNext(
    currentVersion: current,
    labels: labels,
    existingTags: existingTags,
  );

  stdout.writeln('Current Version : ${current?.versionName ?? "none"}');
  stdout.writeln('Next Version    : ${next.versionName}');
  stdout.writeln('Next Tag        : ${next.tagName}');
  stdout.writeln('Next VersionCode: ${next.versionCode}');
  stdout.writeln('Is PreRelease   : ${next.isPreRelease}');
  stdout.writeln('Channel         : ${next.preReleaseChannel ?? "stable"}');

  if (updatePubspec) {
    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      var content = pubspecFile.readAsStringSync();
      final versionRegex = RegExp(r'^version:\s*.*$', multiLine: true);
      final newVersionLine = 'version: ${next.versionName}+${next.versionCode}';
      if (versionRegex.hasMatch(content)) {
        content = content.replaceFirst(versionRegex, newVersionLine);
      } else {
        // Insert after name line
        content = content.replaceFirst(
          RegExp(r'^name:\s*.*$', multiLine: true),
          'name: offlink\n$newVersionLine',
        );
      }
      pubspecFile.writeAsStringSync(content);
      stdout.writeln('Updated pubspec.yaml with $newVersionLine');
    }
  }

  if (githubOutputFile != null && githubOutputFile.isNotEmpty) {
    final outputFile = File(githubOutputFile);
    final sink = outputFile.openWrite(mode: FileMode.append);
    sink.writeln('version=${next.versionName}');
    sink.writeln('tag=${next.tagName}');
    sink.writeln('version_code=${next.versionCode}');
    sink.writeln('is_prerelease=${next.isPreRelease}');
    sink.writeln('channel=${next.preReleaseChannel ?? "stable"}');
    sink.close();
  }
}
