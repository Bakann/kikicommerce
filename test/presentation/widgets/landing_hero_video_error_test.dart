import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/landing_hero_video_error.dart';

void main() {
  group('looksLikeVideoAbortError', () {
    test('treats AbortError rejections as benign', () {
      expect(
        looksLikeVideoAbortError(Exception('AbortError: aborted')),
        isTrue,
      );
      expect(
        looksLikeVideoAbortError(
          'The play() request was interrupted by a call to pause().',
        ),
        isTrue,
      );
    });

    test('does not match genuine media failures', () {
      expect(looksLikeVideoAbortError(Exception('NotSupportedError')), isFalse);
      expect(looksLikeVideoAbortError('CORS request blocked'), isFalse);
      expect(looksLikeVideoAbortError(Exception('404 Not Found')), isFalse);
    });
  });
}
