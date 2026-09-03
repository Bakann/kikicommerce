import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_section_defaults.dart';

void main() {
  group('defaultConfigFor', () {
    test('returns a parseable payload for every CmsSectionType', () {
      for (final type in CmsSectionType.values) {
        final config = defaultConfigFor(type);
        final record = CmsSectionRecord(
          id: 's',
          pageId: 'p',
          sectionId: 's',
          sectionType: type,
          rawSectionType: type.wireName,
          position: 0,
          isActive: true,
          config: config,
        );
        final parsed = parseCmsSection(record);
        expect(
          parsed,
          isNot(isA<CmsUnknownSection>()),
          reason: 'Default config for ${type.wireName} must parse cleanly',
        );
      }
    });

    test('hero default has a non-empty title and a valid CTA', () {
      final config = defaultConfigFor(CmsSectionType.heroCampaign);
      expect(config['title'], isA<String>());
      expect((config['title'] as String).isNotEmpty, isTrue);
      final cta = config['primaryCta'] as Map<String, dynamic>;
      expect(cta['label'], isNotEmpty);
      expect(cta['href'], startsWith('/'));
    });

    test('list-based defaults start empty', () {
      expect(
        (defaultConfigFor(CmsSectionType.categoryTiles)['tiles'] as List),
        isEmpty,
      );
      expect(
        (defaultConfigFor(CmsSectionType.featuredProducts)['productIds']
            as List),
        isEmpty,
      );
      expect(
        (defaultConfigFor(CmsSectionType.serviceCards)['cards'] as List),
        isEmpty,
      );
      expect(
        (defaultConfigFor(CmsSectionType.mixedProductGrid)['inserts'] as List),
        isEmpty,
      );
    });
  });

  group('sectionTypeLabel', () {
    test('returns a non-empty French label for every type', () {
      for (final type in CmsSectionType.values) {
        final label = sectionTypeLabel(type);
        expect(label, isNotEmpty);
      }
    });
  });
}
