// `Override` lives in the `riverpod` core package (a transitive dep brought in
// by flutter_riverpod).
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';

List<Override> storefrontNetworkTestOverrides() => [
  cmsPageRepositoryProvider.overrideWithValue(const FakeCmsPageRepository()),
  storefrontSettingsRepositoryProvider.overrideWithValue(
    const FakeStorefrontSettingsRepository(),
  ),
];

class FakeCmsPageRepository implements CmsPageRepository {
  const FakeCmsPageRepository();

  @override
  Future<CmsPageLoadResult> fetchPage({
    required String code,
    required String locale,
  }) async => const CmsPageMissing();

  @override
  Future<CmsPageLoadResult> fetchPlpForCategory({
    required String categoryId,
    required String locale,
  }) async => const CmsPageMissing();
}

class FakeStorefrontSettingsRepository implements StorefrontSettingsRepository {
  const FakeStorefrontSettingsRepository();

  @override
  Future<StorefrontActiveTheme> getActiveTheme() async =>
      StorefrontActiveTheme.fallback;

  @override
  Future<StorefrontBrandSettings> getBrandSettings() async =>
      StorefrontBrandSettings.fallback;

  @override
  Future<StorefrontNavigationSettings> getNavigationSettings() async =>
      StorefrontNavigationSettings.fallback;

  @override
  Future<void> saveActiveTheme({
    required String authToken,
    required StorefrontTheme theme,
    String? existingRecordId,
  }) async {}
}
