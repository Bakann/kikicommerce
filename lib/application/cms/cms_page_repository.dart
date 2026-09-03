import 'cms_models.dart';

class CmsPageBundle {
  final CmsPageRecord page;
  final List<CmsSectionConfig> sections;

  const CmsPageBundle({required this.page, required this.sections});
}

sealed class CmsPageLoadResult {
  const CmsPageLoadResult();
}

final class CmsPageFound extends CmsPageLoadResult {
  final CmsPageBundle bundle;

  const CmsPageFound(this.bundle);
}

final class CmsPageMissing extends CmsPageLoadResult {
  const CmsPageMissing();
}

final class CmsPageFailure extends CmsPageLoadResult {
  final Object error;
  final StackTrace stackTrace;

  const CmsPageFailure(this.error, this.stackTrace);
}

abstract class CmsPageRepository {
  /// Returns the active page for `(code, locale)` together with its parsed
  /// sections sorted by position. Missing pages are expected and distinct from
  /// load failures so callers can decide whether to fall back.
  Future<CmsPageLoadResult> fetchPage({
    required String code,
    required String locale,
  });

  /// Returns the active PLP page attached to a catalog category. This is used
  /// by `/catalog/:categorySlug`; absence is expected and should fall back to
  /// the classic product list.
  Future<CmsPageLoadResult> fetchPlpForCategory({
    required String categoryId,
    required String locale,
  });
}
