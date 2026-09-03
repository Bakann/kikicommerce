import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/pending_media_provider.dart';

void main() {
  group('pendingMediaProvider', () {
    test('clear only removes the matching version for a media id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingMediaProvider.notifier);

      final firstVersion = notifier.set('media-1', Uint8List.fromList([1]));
      final secondVersion = notifier.set('media-1', Uint8List.fromList([2]));

      expect(firstVersion, 1);
      expect(secondVersion, 2);
      expect(container.read(pendingMediaProvider)['media-1']?.version, 2);

      notifier.clear('media-1', firstVersion);
      expect(container.read(pendingMediaProvider)['media-1']?.version, 2);

      notifier.clear('media-1', secondVersion);
      expect(
        container.read(pendingMediaProvider).containsKey('media-1'),
        isFalse,
      );
    });

    test('pendingMediaForProvider selects one media entry', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pendingMediaProvider.notifier);

      notifier.set('media-1', Uint8List.fromList([1]));
      notifier.set('media-2', Uint8List.fromList([2]));

      expect(container.read(pendingMediaForProvider('media-1'))?.version, 1);
      expect(container.read(pendingMediaForProvider('missing-media')), isNull);
    });
  });
}
