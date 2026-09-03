import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/utils/media_upload_guidance.dart';

void main() {
  group('advisoryForImageUpload', () {
    test('returns info for a light image', () {
      final advisory = advisoryForImageUpload(400 * 1024);

      expect(advisory.level, MediaUploadAdvisoryLevel.info);
      expect(advisory.canUpload, isTrue);
    });

    test('returns warning for a heavy but allowed image', () {
      final advisory = advisoryForImageUpload(3 * 1024 * 1024);

      expect(advisory.level, MediaUploadAdvisoryLevel.warning);
      expect(advisory.canUpload, isTrue);
    });

    test('returns error above the PocketBase limit', () {
      final advisory = advisoryForImageUpload(
        mediaUploadPocketBaseMaxBytes + 1,
      );

      expect(advisory.level, MediaUploadAdvisoryLevel.error);
      expect(advisory.canUpload, isTrue);
    });
  });

  group('formatBytesForHumans', () {
    test('formats megabytes cleanly', () {
      expect(formatBytesForHumans(1572864), '1.5 MB');
    });
  });
}
