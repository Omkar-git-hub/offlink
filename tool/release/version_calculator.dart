import 'dart:io';
import 'pr_classifier.dart';

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

  /// Calculates the next [SemanticVersion] based on PR title, labels, and existing tags.
  static SemanticVersion calculateNext({
    SemanticVersion? currentVersion,
    String? prTitle,
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
    final prClassification = prTitle != null && prTitle.isNotEmpty
        ? PrClassifier.parse(prTitle)
        : null;

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
    } else if (prClassification != null) {
      if (prClassification.isBreaking) {
        // Breaking change
        if (current.isPreRelease) {
          nextMinor = current.minor + 1;
          nextPatch = 0;
          nextIteration = 1;
        } else {
          nextMajor = current.major + 1;
          nextMinor = 0;
          nextPatch = 0;
        }
      } else if (prClassification.action == ReleaseAction.release) {
        if (current.isPreRelease) {
          nextIteration = (current.preReleaseIteration ?? 0) + 1;
        } else {
          if (prClassification.type == 'feat') {
            nextMinor = current.minor + 1;
            nextPatch = 0;
          } else {
            nextPatch = current.patch + 1;
          }
        }
      }
    } else {
      // Default behavior when no specific release label or PR classification is present:
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

  /// Determines whether a release should be skipped based on PR title, PR labels, or commit message.
  static bool isReleaseSkipped(
    List<String> labels, {
    String? commitMessage,
    String? prTitle,
  }) {
    if (prTitle != null && prTitle.trim().isNotEmpty) {
      final classification = PrClassifier.parse(prTitle);
      if (classification != null && !classification.shouldRelease) {
        return true;
      }
    }
    final normalized = labels.map((l) => l.toLowerCase().trim()).toSet();
    if (normalized.contains('release:skip') ||
        normalized.contains('no-release') ||
        normalized.contains('skip-release') ||
        normalized.contains('skip:release')) {
      return true;
    }
    if (commitMessage != null) {
      final msg = commitMessage.toLowerCase();
      if (msg.contains('[skip release]') ||
          msg.contains('[no release]') ||
          msg.contains('[release skip]')) {
        return true;
      }
    }
    return false;
  }
}

/// CLI entrypoint for release automation.
void main(List<String> args) {
  List<String> labels = [];
  String? prTitle = Platform.environment['PR_TITLE'];
  String? commitMessage = Platform.environment['COMMIT_MESSAGE'];
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
    } else if (arg.startsWith('--pr-title=')) {
      prTitle = arg.substring('--pr-title='.length);
    } else if (arg.startsWith('--commit-message=')) {
      commitMessage = arg.substring('--commit-message='.length);
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

  final prClassification = prTitle != null && prTitle.isNotEmpty
      ? PrClassifier.parse(prTitle)
      : null;

  final shouldSkip = SemanticVersion.isReleaseSkipped(
    labels,
    commitMessage: commitMessage,
    prTitle: prTitle,
  );

  // Fetch git tags
  final gitResult = Process.runSync('git', ['tag', '-l']);
  final existingTags = (gitResult.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  // Find latest tag and monotonic highest version code
  SemanticVersion? latestVersion;
  int highestVersionCode = 0;
  int countValidTags = 0;

  for (final tag in existingTags) {
    final parsed = SemanticVersion.parse(tag);
    if (parsed != null) {
      countValidTags++;
      if (parsed.versionCode > highestVersionCode) {
        highestVersionCode = parsed.versionCode;
      }
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

  final baselineVersionCode = highestVersionCode > countValidTags
      ? highestVersionCode
      : countValidTags;

  final current = latestVersion != null
      ? SemanticVersion(
          major: latestVersion.major,
          minor: latestVersion.minor,
          patch: latestVersion.patch,
          preReleaseChannel: latestVersion.preReleaseChannel,
          preReleaseIteration: latestVersion.preReleaseIteration,
          versionCode: baselineVersionCode > 0 ? baselineVersionCode : 1,
        )
      : null;

  final next = SemanticVersion.calculateNext(
    currentVersion: current,
    prTitle: prTitle,
    labels: labels,
    existingTags: existingTags,
  );

  stdout.writeln('PR Title        : ${prTitle ?? "(none)"}');
  stdout.writeln('PR Type         : ${prClassification?.type ?? "(none)"}');
  stdout.writeln('Current Version : ${current?.versionName ?? "none"}');
  stdout.writeln('Next Version    : ${next.versionName}');
  stdout.writeln('Next Tag        : ${next.tagName}');
  stdout.writeln('Next VersionCode: ${next.versionCode}');
  stdout.writeln('Is PreRelease   : ${next.isPreRelease}');
  stdout.writeln('Channel         : ${next.preReleaseChannel ?? "stable"}');
  stdout.writeln('Should Release  : ${!shouldSkip}');

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
    sink.writeln('should_release=${!shouldSkip}');
    if (prClassification != null) {
      sink.writeln('pr_type=${prClassification.type}');
      sink.writeln('pr_scope=${prClassification.scope ?? ""}');
      sink.writeln('is_breaking=${prClassification.isBreaking}');
    }
    sink.close();
  }
}
