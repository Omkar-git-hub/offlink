import 'dart:io';

/// Classification of a pull request based on Conventional Commits conventions.
enum ReleaseAction {
  /// Triggers a regular pre-release (alpha increment) or minor/patch in stable.
  release,

  /// Triggers a breaking change release (minor bump during alpha, major in stable).
  breakingRelease,

  /// No release is triggered (docs, test, chore, ci, refactor).
  noRelease,
}

/// Structured result of PR title classification.
class PrClassification {
  const PrClassification({
    required this.type,
    this.scope,
    required this.isBreaking,
    required this.description,
    required this.action,
    required this.rawTitle,
  });

  final String type;
  final String? scope;
  final bool isBreaking;
  final String description;
  final ReleaseAction action;
  final String rawTitle;

  bool get shouldRelease =>
      action == ReleaseAction.release ||
      action == ReleaseAction.breakingRelease;

  @override
  String toString() =>
      'PrClassification(type: $type, scope: $scope, isBreaking: $isBreaking, action: $action)';
}

/// Utility for parsing and classifying PR titles using Conventional Commits.
class PrClassifier {
  const PrClassifier();

  /// Regex pattern supporting: `<type>(<scope>)<!>: <description>`
  /// Examples:
  /// - feat: add mesh routing
  /// - fix(ble): resolve service discovery
  /// - feat!: breaking api change
  /// - feat(api)!: breaking api change
  static final RegExp conventionalPattern = RegExp(
    r'^(?<type>[a-zA-Z]+)(?:\((?<scope>[a-zA-Z0-9_\-.,\/]+)\))?(?<breaking>!)?:\s+(?<description>.+)$',
  );

  /// Types that trigger a standard release.
  static const Set<String> releaseTypes = {'feat', 'fix', 'perf'};

  /// Types that never trigger a release.
  static const Set<String> noReleaseTypes = {
    'docs',
    'test',
    'chore',
    'ci',
    'style',
    'build',
  };

  /// Parses a PR title and returns a [PrClassification], or null if invalid format.
  static PrClassification? parse(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return null;

    final match = conventionalPattern.firstMatch(trimmed);
    if (match == null) return null;

    final type = match.namedGroup('type')!.toLowerCase();
    final scope = match.namedGroup('scope');
    final isBreaking =
        match.namedGroup('breaking') == '!' ||
        trimmed.contains('BREAKING CHANGE');
    final description = match.namedGroup('description')!.trim();

    ReleaseAction action;
    if (isBreaking) {
      action = ReleaseAction.breakingRelease;
    } else if (releaseTypes.contains(type)) {
      action = ReleaseAction.release;
    } else if (type == 'refactor') {
      // Refactor triggers release only if explicitly marked with [release] or breaking
      if (description.toLowerCase().contains('[release]') ||
          description.toLowerCase().contains('user-visible')) {
        action = ReleaseAction.release;
      } else {
        action = ReleaseAction.noRelease;
      }
    } else if (noReleaseTypes.contains(type)) {
      action = ReleaseAction.noRelease;
    } else {
      // Unknown conventional type defaults to no-release
      action = ReleaseAction.noRelease;
    }

    return PrClassification(
      type: type,
      scope: scope,
      isBreaking: isBreaking,
      description: description,
      action: action,
      rawTitle: trimmed,
    );
  }

  /// Validates a PR title and returns an error message if invalid, or null if valid.
  static String? validate(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) {
      return 'PR title must not be empty.';
    }

    final classification = parse(trimmed);
    if (classification == null) {
      return '''
Invalid PR title: "$trimmed"
Offlink enforces Conventional PR Titles for automated release tracking.

Expected format: <type>(<scope>): <description>
Or breaking:     <type>(<scope>)!: <description>

Supported Types:
  feat:     New user-facing feature (triggers release)
  fix:      Bug fix or resilience enhancement (triggers release)
  perf:     Performance or battery optimization (triggers release)
  feat!:    Breaking feature change (triggers minor bump)
  fix!:     Breaking fix (triggers minor bump)
  docs:     Documentation changes only (no release)
  test:     Unit, widget, or integration tests only (no release)
  chore:    Routine maintenance or dependency updates (no release)
  ci:       CI/CD workflows and release automation (no release)
  refactor: Code restructuring with no behavior change (no release)

Examples:
  feat(bluetooth): add adaptive advertising interval
  fix(mesh): resolve packet loss during multi-hop relay
  docs: update automated release pipeline documentation
  chore(deps): bump flutter dependencies
''';
    }

    return null;
  }
}

/// CLI entrypoint for PR classification and validation.
void main(List<String> args) {
  String? validateTitle;
  String? prTitle;
  String? githubOutputFile = Platform.environment['GITHUB_OUTPUT'];

  for (final arg in args) {
    if (arg.startsWith('--validate-title=')) {
      validateTitle = arg.substring('--validate-title='.length);
    } else if (arg.startsWith('--pr-title=')) {
      prTitle = arg.substring('--pr-title='.length);
    } else if (arg.startsWith('--github-output=')) {
      githubOutputFile = arg.substring('--github-output='.length);
    }
  }

  // Handle validation mode
  if (validateTitle != null) {
    final error = PrClassifier.validate(validateTitle);
    if (error != null) {
      stderr.writeln(error);
      exit(1);
    }
    final classification = PrClassifier.parse(validateTitle)!;
    stdout.writeln('PR title is valid: "${classification.rawTitle}"');
    stdout.writeln('  Type       : ${classification.type}');
    stdout.writeln('  Scope      : ${classification.scope ?? "(none)"}');
    stdout.writeln('  Breaking   : ${classification.isBreaking}');
    stdout.writeln('  Action     : ${classification.action.name}');
    stdout.writeln('  Will Release: ${classification.shouldRelease}');
    exit(0);
  }

  // Handle classification mode
  final title = prTitle ?? Platform.environment['PR_TITLE'] ?? '';
  final classification = PrClassifier.parse(title);

  final shouldRelease = classification?.shouldRelease ?? false;
  final releaseType = classification?.action.name ?? 'noRelease';
  final isBreaking = classification?.isBreaking ?? false;

  stdout.writeln('PR Title      : "$title"');
  stdout.writeln('Should Release: $shouldRelease');
  stdout.writeln('Release Type  : $releaseType');
  stdout.writeln('Is Breaking   : $isBreaking');

  if (githubOutputFile != null && githubOutputFile.isNotEmpty) {
    final file = File(githubOutputFile);
    final sink = file.openWrite(mode: FileMode.append);
    sink.writeln('should_release=$shouldRelease');
    sink.writeln('release_type=$releaseType');
    sink.writeln('is_breaking=$isBreaking');
    if (classification != null) {
      sink.writeln('pr_type=${classification.type}');
      sink.writeln('pr_scope=${classification.scope ?? ""}');
    }
    sink.close();
  }
}
