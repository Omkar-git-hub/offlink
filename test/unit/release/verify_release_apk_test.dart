import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/release/verify_release_apk.dart';

void main() {
  group('ApkVerifier Badging Parser', () {
    test('correctly extracts package, versionCode, and versionName', () {
      const sampleBadging = '''
package: name='io.github.omkar_git_hub.offlink' versionCode='2' versionName='0.1.0-alpha.2' platformBuildVersionName='16' platformBuildVersionCode='36' compileSdkVersion='36' compileSdkVersionCodename='16'
sdkVersion:'24'
targetSdkVersion:'36'
uses-permission: name='android.permission.BLUETOOTH'
application-label:'offlink'
''';

      final parsed = ApkVerifier.parseAaptBadging(sampleBadging);
      expect(parsed['packageName'], 'io.github.omkar_git_hub.offlink');
      expect(parsed['versionCode'], 2);
      expect(parsed['versionName'], '0.1.0-alpha.2');
    });

    test('returns empty map when pattern does not match', () {
      final parsed = ApkVerifier.parseAaptBadging('invalid output');
      expect(parsed, isEmpty);
    });
  });

  group('ApkVerifier ApkSigner Parser', () {
    test('extracts v2 scheme and certificate fingerprints', () {
      const sampleSignerOutput = '''
Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
Number of signers: 1

Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: df03904dbb6579c665a55f39c53472056048495c004422f0add2153924de06df
Signer #1 certificate SHA-1 digest: 1a4551631d083108a5b34aebd6102e947882652c
''';

      final parsed = ApkVerifier.parseApkSignerOutput(sampleSignerOutput);
      expect(parsed['verified'], isTrue);
      expect(parsed['v2'], isTrue);
      expect(parsed['v3'], isFalse);
      expect(parsed['certDn'], 'C=US, O=Android, CN=Android Debug');
      expect(
        parsed['certSha256'],
        'df03904dbb6579c665a55f39c53472056048495c004422f0add2153924de06df',
      );
    });
  });

  group('ApkVerifier File Checks', () {
    test('fails gracefully when APK file does not exist', () {
      final missingFile = File('non_existent_file.apk');
      final result = ApkVerifier.verify(apkFile: missingFile);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('APK file not found'));
    });

    test('fails gracefully when APK file is 0 bytes', () {
      final tempFile = File('${Directory.systemTemp.path}/empty_test.apk');
      tempFile.writeAsBytesSync([]);

      final result = ApkVerifier.verify(apkFile: tempFile);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('0 bytes'));

      tempFile.deleteSync();
    });

    test('computes valid SHA-256 for non-empty file', () {
      final tempFile = File('${Directory.systemTemp.path}/sample_test.bin');
      tempFile.writeAsStringSync('Offlink Secure Mesh');

      final hash = ApkVerifier.calculateSha256(tempFile);
      expect(hash, isNotEmpty);
      expect(hash.length, 64);

      tempFile.deleteSync();
    });
  });
}
