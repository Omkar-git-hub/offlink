import 'dart:io';

class ReleaseNotesGenerator {
  const ReleaseNotesGenerator();

  /// Categorizes git commit messages into structured release sections.
  static Map<String, List<String>> categorizeCommits(List<String> rawLines) {
    final Map<String, List<String>> categories = {
      '🚀 Features & Enhancements': [],
      '🔒 Security Hardening': [],
      '⚡ Battery & Performance': [],
      '🐛 Fixes & Resilience': [],
      '📚 Documentation': [],
      '🔧 Tooling & CI/CD': [],
      '📦 Other Changes': [],
    };

    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Extract subject (handling "subject|hash|author" format)
      final parts = trimmed.split('|');
      final subject = parts.first.trim();
      final hash = parts.length > 1 ? parts[1].trim() : '';

      final lower = subject.toLowerCase();

      // Skip internal merge commits if duplicate
      if (lower.startsWith('merge branch ') ||
          lower.startsWith('merge pull request #')) {
        // We can extract PR title if present
        continue;
      }

      final item = hash.isNotEmpty ? '$subject ($hash)' : subject;

      if (lower.contains('feat') || lower.contains('feature')) {
        categories['🚀 Features & Enhancements']!.add(item);
      } else if (lower.contains('sec') ||
          lower.contains('security') ||
          lower.contains('crypto') ||
          lower.contains('abuse') ||
          lower.contains('fingerprint')) {
        categories['🔒 Security Hardening']!.add(item);
      } else if (lower.contains('battery') ||
          lower.contains('power') ||
          lower.contains('perf')) {
        categories['⚡ Battery & Performance']!.add(item);
      } else if (lower.contains('fix') ||
          lower.contains('bug') ||
          lower.contains('resilience')) {
        categories['🐛 Fixes & Resilience']!.add(item);
      } else if (lower.contains('doc') ||
          lower.contains('docs') ||
          lower.contains('readme')) {
        categories['📚 Documentation']!.add(item);
      } else if (lower.contains('ci') ||
          lower.contains('workflow') ||
          lower.contains('build') ||
          lower.contains('tool') ||
          lower.contains('release')) {
        categories['🔧 Tooling & CI/CD']!.add(item);
      } else {
        categories['📦 Other Changes']!.add(item);
      }
    }

    return categories;
  }

  /// Builds the complete Markdown release notes.
  static String buildNotes({
    required String version,
    required String channel,
    required bool isPreRelease,
    required Map<String, List<String>> categorized,
    String? sourceRepoUrl = 'https://github.com/Omkar-git-hub/offlink',
    String? releaseDate,
  }) {
    final date =
        releaseDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final buffer = StringBuffer();

    buffer.writeln('# Offlink v$version');
    buffer.writeln();
    buffer.writeln(
      '**Release Classification**: ${isPreRelease ? (channel == "beta" ? "Beta (Pre-Release)" : "Developer Alpha (Pre-Release)") : "General Availability (Stable)"}',
    );
    buffer.writeln('**Release Date**: $date');
    buffer.writeln('**Source Repository**: $sourceRepoUrl');
    buffer.writeln(
      '**Android Compatibility**: Android 7.0 Nougat (API 24) to Android 16 (API 36)',
    );
    buffer.writeln(
      '**Supported Architectures**: `arm64-v8a`, `armeabi-v7a`, `x86_64`',
    );
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    bool hasAnyCategory = false;
    for (final entry in categorized.entries) {
      if (entry.value.isNotEmpty) {
        hasAnyCategory = true;
        buffer.writeln('### ${entry.key}');
        for (final item in entry.value) {
          buffer.writeln('- $item');
        }
        buffer.writeln();
      }
    }

    if (!hasAnyCategory) {
      buffer.writeln('### 🚀 Release Highlights');
      buffer.writeln('- Automated release build for version $version.');
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## Verification & Security');
    buffer.writeln('- Checksums are available in `SHA256SUMS.txt`.');
    buffer.writeln(
      '- For signature and hash verification instructions, visit [APK Verification Guide](https://github.com/Omkar-git-hub/offlink-releases/blob/main/docs/verification/apk-verification.md).',
    );
    buffer.writeln(
      '- To report security issues responsibly, please see [Security Policy](https://github.com/Omkar-git-hub/offlink-releases/blob/main/SECURITY.md).',
    );

    return buffer.toString();
  }

  /// Prepends a new release section to CHANGELOG.md.
  static void prependToChangelog({
    required File changelogFile,
    required String version,
    required Map<String, List<String>> categorized,
    String? releaseDate,
  }) {
    final date =
        releaseDate ?? DateTime.now().toIso8601String().substring(0, 10);
    final newSection = StringBuffer();

    newSection.writeln('## [$version] - $date');
    newSection.writeln();

    for (final entry in categorized.entries) {
      if (entry.value.isNotEmpty) {
        newSection.writeln('### ${entry.key}');
        for (final item in entry.value) {
          newSection.writeln('- $item');
        }
        newSection.writeln();
      }
    }

    if (changelogFile.existsSync()) {
      final existing = changelogFile.readAsStringSync();
      // Insert after header (# Changelog ... )
      final headerIndex = existing.indexOf('## [');
      if (headerIndex != -1) {
        final prefix = existing.substring(0, headerIndex);
        final rest = existing.substring(headerIndex);
        changelogFile.writeAsStringSync('$prefix$newSection$rest');
      } else {
        changelogFile.writeAsStringSync('$newSection\n$existing');
      }
    } else {
      changelogFile.writeAsStringSync('# Changelog\n\n$newSection');
    }
  }
}

/// CLI entrypoint.
void main(List<String> args) {
  String version = '0.1.0-alpha.2';
  String channel = 'alpha';
  bool isPreRelease = true;
  String? fromRef;
  String toRef = 'HEAD';
  String? outputFile;
  bool updateChangelog = false;
  String changelogPath = 'CHANGELOG.md';

  String? prTitle = Platform.environment['PR_TITLE'];

  for (final arg in args) {
    if (arg.startsWith('--version=')) {
      version = arg.substring('--version='.length);
    } else if (arg.startsWith('--tag=')) {
      final tag = arg.substring('--tag='.length);
      if (tag.startsWith('v')) {
        version = tag.substring(1);
      }
    } else if (arg.startsWith('--channel=')) {
      channel = arg.substring('--channel='.length);
    } else if (arg.startsWith('--pr-title=')) {
      prTitle = arg.substring('--pr-title='.length);
    } else if (arg.startsWith('--prerelease=')) {
      isPreRelease =
          arg.substring('--prerelease='.length).toLowerCase() == 'true';

    } else if (arg.startsWith('--from-ref=')) {
      fromRef = arg.substring('--from-ref='.length);
    } else if (arg.startsWith('--to-ref=')) {
      toRef = arg.substring('--to-ref='.length);
    } else if (arg.startsWith('--output=')) {
      outputFile = arg.substring('--output='.length);
    } else if (arg.startsWith('--output-file=')) {
      outputFile = arg.substring('--output-file='.length);
    } else if (arg == '--update-changelog') {
      updateChangelog = true;
    } else if (arg.startsWith('--changelog-path=')) {
      changelogPath = arg.substring('--changelog-path='.length);
    }
  }

  // If fromRef is not provided, find previous tag
  if (fromRef == null) {
    final tagsResult = Process.runSync('git', ['tag', '--sort=-creatordate']);
    final tags = (tagsResult.stdout as String)
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (tags.isNotEmpty) {
      fromRef = tags.first;
    }
  }

  List<String> rawCommits = [];
  if (fromRef != null && fromRef.isNotEmpty) {
    final logResult = Process.runSync('git', [
      'log',
      '$fromRef..$toRef',
      '--pretty=format:%s|%h|%an',
    ]);
    rawCommits = (logResult.stdout as String).split('\n');
  } else {
    final logResult = Process.runSync('git', [
      'log',
      '-n',
      '20',
      '--pretty=format:%s|%h|%an',
    ]);
    rawCommits = (logResult.stdout as String).split('\n');
  }

  // If no commit history found between tags, but a PR title is provided, use it
  if (rawCommits.every((c) => c.trim().isEmpty) &&
      prTitle != null &&
      prTitle.isNotEmpty) {
    rawCommits = [prTitle];
  }

  final categorized = ReleaseNotesGenerator.categorizeCommits(rawCommits);
  final markdown = ReleaseNotesGenerator.buildNotes(
    version: version,
    channel: channel,
    isPreRelease: isPreRelease,
    categorized: categorized,
  );

  if (outputFile != null && outputFile.isNotEmpty) {
    final target = File(outputFile);
    if (!target.parent.existsSync()) {
      target.parent.createSync(recursive: true);
    }
    target.writeAsStringSync(markdown);
    stdout.writeln('Wrote release notes to $outputFile');
  } else {
    stdout.writeln(markdown);
  }

  if (updateChangelog) {
    ReleaseNotesGenerator.prependToChangelog(
      changelogFile: File(changelogPath),
      version: version,
      categorized: categorized,
    );
    stdout.writeln('Updated changelog at $changelogPath');
  }
}
