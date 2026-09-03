/// Write-side repository for the CMS. All methods require an admin auth token
/// since `pages` and `page_sections` collections only allow authenticated
/// writes (cf. PocketBase migrations).
abstract interface class CmsPageEditorRepository {
  Future<String> createPlpPage({
    required String authToken,
    required String code,
    required String locale,
    required String title,
    required String sourceCategoryId,
    String? seoTitle,
    String? seoDescription,
  });

  Future<void> createSection({
    required String authToken,
    required String pageId,
    required String sectionId,
    required String sectionType,
    required int position,
    required bool isActive,
    required Map<String, dynamic> config,
  });

  Future<void> updateSection({
    required String authToken,
    required String sectionRecordId,
    required Map<String, dynamic> patch,
  });

  Future<void> deleteSection({
    required String authToken,
    required String sectionRecordId,
  });
}
