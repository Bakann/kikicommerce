import '../../core/utils/search_index_utils.dart';
import '../../core/utils/string_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../admin/save_admin_record.dart';

sealed class SaveProductTextResult {
  const SaveProductTextResult();
}

class SaveProductTextNoChange extends SaveProductTextResult {
  const SaveProductTextNoChange();
}

class SaveProductTextSaved extends SaveProductTextResult {
  const SaveProductTextSaved();
}

class SaveProductTextFailure extends SaveProductTextResult {
  final Object error;

  const SaveProductTextFailure(this.error);
}

class SaveProductText {
  final SaveAdminRecord saveAdminRecord;

  const SaveProductText(this.saveAdminRecord);

  Future<SaveProductTextResult> call({
    required String baseUrl,
    required String authToken,
    required CatalogProduct product,
    String? name,
    String? summary,
  }) async {
    final normalizedName = name?.trim();
    final normalizedSummary = summary?.trim() ?? '';
    final currentVisibleSummary = stripHtml(product.summary ?? '');
    final updates = <String, dynamic>{};

    if (normalizedName != null && normalizedName != product.name.trim()) {
      updates['name'] = normalizedName;
    }

    if (summary != null && normalizedSummary != currentVisibleSummary.trim()) {
      updates['summary'] = normalizedSummary;
    }

    if (updates.isEmpty) {
      return const SaveProductTextNoChange();
    }

    updates['searchIndex'] = buildProductSearchIndex(
      buildProductSearchData(
        product,
        name: normalizedName,
        summary: summary == null ? null : normalizedSummary,
      ),
    );

    try {
      await saveAdminRecord(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'products',
        recordId: product.id,
        data: updates,
      );
      return const SaveProductTextSaved();
    } catch (error) {
      return SaveProductTextFailure(error);
    }
  }
}

Map<String, dynamic> buildProductSearchData(
  CatalogProduct product, {
  String? name,
  String? summary,
}) {
  return {
    'code': product.code,
    'name': name ?? product.name,
    'slug': product.slug,
    'summary': summary ?? stripHtml(product.summary ?? ''),
    'description': product.description,
    'ean': product.ean,
    'gender': product.gender,
    'productType': product.productType,
    'brand': product.brand,
  };
}
