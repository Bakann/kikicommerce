import 'package:flutter/foundation.dart';

import '../../application/cms/cms_models.dart';
import '../../application/cms/cms_page_repository.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../api/pocketbase_client.dart';

class PocketBaseCmsPageRepository implements CmsPageRepository {
  final PocketBaseClient client;

  const PocketBaseCmsPageRepository({required this.client});

  @override
  Future<CmsPageLoadResult> fetchPage({
    required String code,
    required String locale,
  }) async {
    try {
      final pageResponse = await client.listRecords<Map<String, dynamic>>(
        'pages',
        filter:
            'code="${escapeFilterValue(code)}" && locale="${escapeFilterValue(locale)}" && isActive=true',
        page: 1,
        perPage: 1,
        fields: 'id,code,locale,title,isActive',
        fromJson: (json) => json,
      );

      if (pageResponse.items.isEmpty) {
        return const CmsPageMissing();
      }

      final page = CmsPageRecord.fromJson(pageResponse.items.first);
      return CmsPageFound(await _fetchBundle(page));
    } catch (error, stackTrace) {
      debugPrint(
        '[cms] Failed to fetch page $code/$locale: $error\n$stackTrace',
      );
      return CmsPageFailure(error, stackTrace);
    }
  }

  @override
  Future<CmsPageLoadResult> fetchPlpForCategory({
    required String categoryId,
    required String locale,
  }) async {
    try {
      final pageResponse = await client.listRecords<Map<String, dynamic>>(
        'pages',
        filter:
            'pageType="plp" && sourceCategory="${escapeFilterValue(categoryId)}" && locale="${escapeFilterValue(locale)}" && isActive=true',
        page: 1,
        perPage: 1,
        fields:
            'id,code,locale,title,isActive,pageType,sourceCategory,seoTitle,seoDescription',
        fromJson: (json) => json,
      );

      if (pageResponse.items.isEmpty) {
        return const CmsPageMissing();
      }

      final page = CmsPageRecord.fromJson(pageResponse.items.first);
      return CmsPageFound(await _fetchBundle(page));
    } catch (error, stackTrace) {
      debugPrint(
        '[cms] Failed to fetch PLP for category $categoryId/$locale: '
        '$error\n$stackTrace',
      );
      return CmsPageFailure(error, stackTrace);
    }
  }

  Future<CmsPageBundle> _fetchBundle(CmsPageRecord page) async {
    final sectionsResponse = await client.listRecords<Map<String, dynamic>>(
      'page_sections',
      filter: 'page="${escapeFilterValue(page.id)}"',
      sort: 'position,created',
      page: 1,
      perPage: 200,
      fields: 'id,page,sectionId,sectionType,position,isActive,config',
      fromJson: (json) => json,
    );

    final sections = sectionsResponse.items
        .map(CmsSectionRecord.fromJson)
        .map(parseCmsSection)
        .toList(growable: false);

    for (final section in sections) {
      if (section is CmsUnknownSection) {
        debugPrint(
          '[cms] Unknown or invalid section ${section.record.sectionId} '
          '(type=${section.record.rawSectionType}, '
          'page=${page.code}/${page.locale}): ${section.parseError ?? 'unsupported type'}',
        );
      }
    }

    return CmsPageBundle(page: page, sections: sections);
  }
}
