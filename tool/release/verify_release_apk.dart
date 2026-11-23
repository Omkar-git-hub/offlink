import 'dart:io';
import 'package:crypto/crypto.dart';

class ApkVerificationResult {
  const ApkVerificationResult({
    required this.isValid,
    required this.fileSize,
    required this.sha256Hash,
    this.packageName,
    this.versionName,
    this.versionCode,
    this.signingSchemeV2 = false,
    this.signerCertDn,
    this.signerCertSha256,
    this.errorMessage,
  });

  final bool isValid;
  final int fileSize;
  final String sha256Hash;
  final String? packageName;
  final String? versionName;
  final int? versionCode;
  final bool signingSchemeV2;
  final String? signerCertDn;
  final String? signerCertSha256;
  final String? errorMessage;
}

class ApkVerifier {
  const ApkVerifier();

  /// Calculates SHA-256 hash of a file.
  static String calculateSha256(File file) {
    final bytes = file.readAsBytesSync();
    return sha256.convert(bytes).toString();
  }

  /// Parses `aapt dump badging` output.
  static Map<String, dynamic> parseAaptBadging(String badgingOutput) {
    final Map<String, dynamic> result = {};

    final packageMatch = RegExp(
      r"package:\s+name='([^']+)'\s+versionCode='([^']+)'\s+versionName='([^']+)'",
    ).firstMatch(badgingOutput);

    if (packageMatch != null) {
      result['packageName'] = packageMatch.group(1);
      result['versionCode'] = int.tryParse(packageMatch.group(2) ?? '');
      result['versionName'] = packageMatch.group(3);
    }

    return result;
  }

  /// Parses `apksigner verify --print-certs` output.
  static Map<String, dynamic> parseApkSignerOutput(String signerOutput) {
    final Map<String, dynamic> result = {
      'verified': signerOutput.contains('Verifies'),
      'v2': signerOutput.contains(
        'Verified using v2 scheme (APK Signature Scheme v2): true',
      ),
      'v3': signerOutput.contains(
        'Verified using v3 scheme (APK Signature Scheme v3): true',
      ),
    };

    final dnMatch = RegExp(
      r"certificate DN:\s+(.+)$",
      multiLine: true,
    ).firstMatch(signerOutput);
    if (dnMatch != null) {
      result['certDn'] = dnMatch.group(1)!.trim();
    }

    final sha256Match = RegExp(
      r"certificate SHA-256 digest:\s+([a-fA-F0-9]+)",
      multiLine: true,
    ).firstMatch(signerOutput);
    if (sha256Match != null) {
      result['certSha256'] = sha256Match.group(1)!.toLowerCase().trim();
    }

    return result;
  }

  /// Verifies an APK against expected parameters.
  static ApkVerificationResult verify({
    required File apkFile,
    String? expectedPackage,
    String? expectedVersion,
    int? expectedVersionCode,
    bool requireProductionSigning = false,
    String? aaptPath,
    String? apksignerPath,
  }) {
    if (!apkFile.existsSync()) {
      return ApkVerificationResult(
        isValid: false,
        fileSize: 0,
        sha256Hash: '',
        errorMessage: 'APK file not found: ${apkFile.path}',
      );
    }

    final fileSize = apkFile.lengthSync();
    if (fileSize == 0) {
      return const ApkVerificationResult(
        isValid: false,
        fileSize: 0,
        sha256Hash: '',
        errorMessage: 'APK file is empty (0 bytes)',
      );
    }

    final hash = calculateSha256(apkFile);

    String? packageName;
    String? versionName;
    int? versionCode;

    // Run aapt if available
    final aaptExec = aaptPath ?? _findAapt();
    if (aaptExec != null) {
      final aaptResult = Process.runSync(aaptExec, [
        'dump',
        'badging',
        apkFile.path,
      ]);
      if (aaptResult.exitCode == 0) {
        final parsed = parseAaptBadging(aaptResult.stdout as String);
        packageName = parsed['packageName'] as String?;
        versionName = parsed['versionName'] as String?;
        versionCode = parsed['versionCode'] as int?;

        if (expectedPackage != null && packageName != expectedPackage) {
          return ApkVerificationResult(
            isValid: false,
            fileSize: fileSize,
            sha256Hash: hash,
            packageName: packageName,
            errorMessage:
                'Package mismatch: expected $expectedPackage, found $packageName',
          );
        }

        if (expectedVersion != null && versionName != expectedVersion) {
          return ApkVerificationResult(
            isValid: false,
            fileSize: fileSize,
            sha256Hash: hash,
            versionName: versionName,
            errorMessage:
                'Version name mismatch: expected $expectedVersion, found $versionName',
          );
        }

        if (expectedVersionCode != null && versionCode != expectedVersionCode) {
          return ApkVerificationResult(
            isValid: false,
            fileSize: fileSize,
            sha256Hash: hash,
            versionCode: versionCode,
            errorMessage:
                'Version code mismatch: expected $expectedVersionCode, found $versionCode',
          );
        }
      }
    }

    // Run apksigner if available
    bool v2 = false;
    String? certDn;
    String? certSha256;

    final apksignerExec = apksignerPath ?? _findApksigner();
    if (apksignerExec != null) {
      final signerResult = Process.runSync(apksignerExec, [
        'verify',
        '--verbose',
        '--print-certs',
        apkFile.path,
      ]);
      if (signerResult.exitCode != 0) {
        return ApkVerificationResult(
          isValid: false,
          fileSize: fileSize,
          sha256Hash: hash,
          errorMessage: 'apksigner verification failed: ${signerResult.stderr}',
        );
      }
      final parsed = parseApkSignerOutput(signerResult.stdout as String);
      v2 = (parsed['v2'] as bool? ?? false) || (parsed['v3'] as bool? ?? false);
      certDn = parsed['certDn'] as String?;
      certSha256 = parsed['certSha256'] as String?;

      if (!v2) {
        return ApkVerificationResult(
          isValid: false,
          fileSize: fileSize,
          sha256Hash: hash,
          errorMessage: 'APK is not signed with v2/v3 scheme',
        );
      }

      if (requireProductionSigning &&
          certDn != null &&
          certDn.contains('CN=Android Debug')) {
        return ApkVerificationResult(
          isValid: false,
          fileSize: fileSize,
          sha256Hash: hash,
          signerCertDn: certDn,
          errorMessage:
              'Production signing required, but APK is signed with Debug keystore ($certDn)',
        );
      }
    }

    return ApkVerificationResult(
      isValid: true,
      fileSize: fileSize,
      sha256Hash: hash,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      signingSchemeV2: v2,
      signerCertDn: certDn,
      signerCertSha256: certSha256,
    );
  }

  static String? _findAapt() {
    // Check PATH
    final which = Platform.isWindows ? 'where' : 'which';
    final res = Process.runSync(which, ['aapt']);
    if (res.exitCode == 0) {
      return (res.stdout as String).split('\n').first.trim();
    }

    // Check Android SDK path
    final androidHome =
        Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (androidHome != null) {
      final buildTools = Directory('$androidHome/build-tools');
      if (buildTools.existsSync()) {
        final dirs = buildTools.listSync().whereType<Directory>().toList()
          ..sort((a, b) => b.path.compareTo(a.path));
        for (final dir in dirs) {
          final candidate = File(
            '${dir.path}/aapt${Platform.isWindows ? ".exe" : ""}',
          );
          if (candidate.existsSync()) {
            return candidate.path;
          }
        }
      }
    }
    return null;
  }

  static String? _findApksigner() {
    final which = Platform.isWindows ? 'where' : 'which';
    final res = Process.runSync(which, ['apksigner']);
    if (res.exitCode == 0) {
      return (res.stdout as String).split('\n').first.trim();
    }

    final androidHome =
        Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (androidHome != null) {
      final buildTools = Directory('$androidHome/build-tools');
      if (buildTools.existsSync()) {
        final dirs = buildTools.listSync().whereType<Directory>().toList()
          ..sort((a, b) => b.path.compareTo(a.path));
        for (final dir in dirs) {
          final candidate = File(
            '${dir.path}/apksigner${Platform.isWindows ? ".bat" : ""}',
          );
          if (candidate.existsSync()) return candidate.path;
        }
      }
    }
    return null;
  }
}

/// CLI entrypoint.
void main(List<String> args) {
  String? apkPath;
  String? expectedPackage = 'io.github.omkar_git_hub.offlink';
  String? expectedVersion;
  int? expectedVersionCode;
  bool requireProduction = false;
  String? checksumFile;
  String? githubOutputFile = Platform.environment['GITHUB_OUTPUT'];

  for (final arg in args) {
    if (arg.startsWith('--apk=')) {
      apkPath = arg.substring('--apk='.length);
    } else if (arg.startsWith('--expected-package=')) {
      expectedPackage = arg.substring('--expected-package='.length);
    } else if (arg.startsWith('--expected-version=')) {
      expectedVersion = arg.substring('--expected-version='.length);
    } else if (arg.startsWith('--expected-version-code=')) {
      expectedVersionCode = int.tryParse(
        arg.substring('--expected-version-code='.length),
      );
    } else if (arg == '--require-production') {
      requireProduction = true;
    } else if (arg.startsWith('--checksum-file=')) {
      checksumFile = arg.substring('--checksum-file='.length);
    } else if (arg.startsWith('--github-output=')) {
      githubOutputFile = arg.substring('--github-output='.length);
    }
  }

  if (apkPath == null || apkPath.isEmpty) {
    stderr.writeln('Error: --apk=<path> argument is required');
    exit(1);
  }

  final apkFile = File(apkPath);
  final result = ApkVerifier.verify(
    apkFile: apkFile,
    expectedPackage: expectedPackage,
    expectedVersion: expectedVersion,
    expectedVersionCode: expectedVersionCode,
    requireProductionSigning: requireProduction,
  );

  if (!result.isValid) {
    stderr.writeln('APK Verification FAILED: ${result.errorMessage}');
    exit(1);
  }

  stdout.writeln('APK Verification PASSED');
  stdout.writeln('File Size        : ${result.fileSize} bytes');
  stdout.writeln('SHA-256 Hash     : ${result.sha256Hash}');
  stdout.writeln('Package Name     : ${result.packageName ?? "uninspected"}');
  stdout.writeln('Version Name     : ${result.versionName ?? "uninspected"}');
  stdout.writeln('Version Code     : ${result.versionCode ?? "uninspected"}');
  stdout.writeln('Signing Scheme v2: ${result.signingSchemeV2}');
  stdout.writeln('Signer Cert DN   : ${result.signerCertDn ?? "uninspected"}');
  stdout.writeln(
    'Signer SHA-256   : ${result.signerCertSha256 ?? "uninspected"}',
  );

  final apkBasename = apkFile.uri.pathSegments.last;
  final checksumLine = '${result.sha256Hash}  $apkBasename\n';

  if (checksumFile != null) {
    File(checksumFile).writeAsStringSync(checksumLine);
    stdout.writeln('Wrote checksum to $checksumFile');
  }

  if (githubOutputFile != null && githubOutputFile.isNotEmpty) {
    final sink = File(githubOutputFile).openWrite(mode: FileMode.append);
    sink.writeln('apk_sha256=${result.sha256Hash}');
    sink.writeln('apk_size=${result.fileSize}');
    sink.writeln('signer_dn=${result.signerCertDn ?? "unknown"}');
    sink.writeln('signer_sha256=${result.signerCertSha256 ?? "unknown"}');
    sink.close();
  }
}
