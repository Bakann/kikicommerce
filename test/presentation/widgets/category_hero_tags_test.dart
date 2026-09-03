import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/category_hero_tags.dart';

void main() {
  group('categoryPlpHeroKeyFromHref', () {
    test('slug PLP href → slug key', () {
      expect(categoryPlpHeroKeyFromHref('/catalog/mercurial'), 'mercurial');
    });

    test('slug PLP href with query → slug key (query ignored)', () {
      expect(
        categoryPlpHeroKeyFromHref('/catalog/mercurial?ref=x'),
        'mercurial',
      );
    });

    test('by-id PLP href → id-prefixed key (matches the by-id route)', () {
      expect(
        categoryPlpHeroKeyFromHref('/catalog?categoryId=cat-1'),
        'id:cat-1',
      );
    });

    test('sport PLP href → category slug key (the /sport route namespace)', () {
      // Regression: sport themes reach their PLP via /sport/<segment>/<slug>,
      // not /catalog — the original gate missed this and never fired.
      expect(
        categoryPlpHeroKeyFromHref('/sport/homme/summer-essentials'),
        'summer-essentials',
      );
    });

    test('sport segment landing (no category) → null', () {
      expect(categoryPlpHeroKeyFromHref('/sport/homme'), isNull);
    });

    test('bare /catalog has no category target → null', () {
      expect(categoryPlpHeroKeyFromHref('/catalog'), isNull);
    });

    test('non-PLP internal href → null', () {
      expect(categoryPlpHeroKeyFromHref('/search'), isNull);
      expect(categoryPlpHeroKeyFromHref('/'), isNull);
    });

    test('external / empty href → null', () {
      expect(categoryPlpHeroKeyFromHref('https://example.com/x'), isNull);
      expect(categoryPlpHeroKeyFromHref('   '), isNull);
    });
  });

  group('categoryPlpHeroTag', () {
    test('is deterministic and namespaced', () {
      expect(categoryPlpHeroTag('mercurial'), 'category-plp-hero-mercurial');
      expect(categoryPlpHeroTag('id:cat-1'), 'category-plp-hero-id:cat-1');
    });

    test('source href and destination slug agree on the same tag', () {
      // The tile derives its key from the href; the PLP route passes the raw
      // slug. Both must produce the identical Hero tag for the flight to pair.
      final keyFromHref = categoryPlpHeroKeyFromHref('/catalog/mercurial')!;
      const slugFromRoute = 'mercurial';
      expect(
        categoryPlpHeroTag(keyFromHref),
        categoryPlpHeroTag(slugFromRoute),
      );
    });
  });
}
