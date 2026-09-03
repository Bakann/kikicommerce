import '../../application/cms/cms_page_editor_repository.dart';
import '../api/pocketbase_client.dart';

class PocketBaseCmsPageEditorRepository implements CmsPageEditorRepository {
  final PocketBaseClient client;

  const PocketBaseCmsPageEditorRepository({required this.client});

  @override
  Future<String> createPlpPage({
    required String authToken,
    required String code,
    required String locale,
    required String title,
    required String sourceCategoryId,
    String? seoTitle,
    String? seoDescription,
  }) async {
    final record = await client.createRecord('pages', <String, dynamic>{
      'code': code,
      'locale': locale,
      'title': title,
      'isActive': true,
      'pageType': 'plp',
      'sourceCategory': sourceCategoryId,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
    }, authToken: authToken);
    return record['id'] as String? ?? '';
  }

  @override
  Future<void> createSection({
    required String authToken,
    required String pageId,
    required String sectionId,
    required String sectionType,
    required int position,
    required bool isActive,
    required Map<String, dynamic> config,
  }) async {
    await client.createRecord('page_sections', <String, dynamic>{
      'page': pageId,
      'sectionId': sectionId,
      'sectionType': sectionType,
      'position': position,
      'isActive': isActive,
      'config': config,
    }, authToken: authToken);
  }

  @override
  Future<void> updateSection({
    required String authToken,
    required String sectionRecordId,
    required Map<String, dynamic> patch,
  }) async {
    await client.updateRecord(
      'page_sections',
      sectionRecordId,
      patch,
      authToken: authToken,
    );
  }

  @override
  Future<void> deleteSection({
    required String authToken,
    required String sectionRecordId,
  }) async {
    await client.deleteRecord(
      'page_sections',
      sectionRecordId,
      authToken: authToken,
    );
  }
}
