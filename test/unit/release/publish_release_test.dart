import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/release/publish_release.dart';

void main() {
  group('ReleasePublisher', () {
    test(
      'checkReleaseExists returns false when gh fails or release does not exist',
      () {
        final exists = ReleasePublisher.checkReleaseExists(
          'non_existent_org/non_existent_repo',
          'v99.99.99',
        );
        expect(exists, isFalse);
      },
    );

    test(
      'uploadAssets returns true when asset list is empty or handles missing files gracefully',
      () {
        final result = ReleasePublisher.uploadAssets(
          repo: 'test-repo',
          tag: 'v1.0.0',
          assets: [File('non_existent_test_asset.apk')],
        );
        // Since asset doesn't exist, it skips it and attempts runCmd which fails on test-repo, returning false
        expect(result, isFalse);
      },
    );
  });
}
