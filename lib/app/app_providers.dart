import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/http_client_provider.dart';
import '../admin/repositories/pocketbase_admin_auth_repository.dart';
import '../admin/repositories/pocketbase_admin_backoffice_repository.dart';
import '../admin/repositories/pocketbase_admin_media_repository.dart';
import '../application/admin/admin_auth_repository.dart';
import '../application/admin/admin_backoffice_repository.dart';
import '../application/admin/admin_media_repository.dart';
import '../application/admin/add_product_gallery_media.dart';
import '../application/admin/assign_product_media.dart';
import '../application/admin/authenticate_admin_user.dart';
import '../application/admin/authenticate_admin_superuser.dart';
import '../application/admin/delete_admin_record.dart';
import '../application/admin/export_catalog_csv.dart';
import '../application/admin/import_catalog_csv.dart';
import '../application/admin/load_admin_collections.dart';
import '../application/admin/replace_media_asset.dart';
import '../application/admin/reorder_category_products.dart';
import '../application/admin/save_admin_record.dart';
import '../application/cart/add_to_cart.dart';
import '../application/cart/cart_guest_session_store.dart';
import '../application/cart/cart_repository.dart';
import '../application/cart/clear_cart.dart';
import '../application/cart/get_active_cart.dart';
import '../application/cart/remove_entry.dart';
import '../application/cart/update_entry_quantity.dart';
import '../application/catalog/category_catalog_repository.dart';
import '../application/catalog/get_active_categories.dart';
import '../application/catalog/get_category_products.dart';
import '../application/catalog/get_category_by_slug.dart';
import '../application/catalog/get_default_category.dart';
import '../application/catalog/get_product_detail.dart';
import '../application/catalog/product_catalog_repository.dart';
import '../application/catalog/product_search_repository.dart';
import '../application/catalog/resolve_product_route.dart';
import '../application/catalog/save_product_price.dart';
import '../application/catalog/save_product_text.dart';
import '../application/catalog/pdp_localized_text_editor.dart';
import '../application/catalog/search_products.dart';
import '../application/navigation/drawer_navigation_repository.dart';
import '../application/navigation/navigation_editor_options.dart';
import '../application/navigation/save_navigation_item.dart';
import '../application/storefront/storefront_brand_settings.dart';
import '../application/storefront/storefront_navigation_settings.dart';
import '../config/api_config.dart';
import '../config/cart_feature_flags.dart';
import '../data/api/pocketbase_client.dart';
import '../data/local/guest_session_store.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/cart_repository_impl.dart';
import '../data/repositories/pocketbase_cms_page_editor_repository.dart';
import '../data/repositories/pocketbase_cms_page_repository.dart';
import '../data/repositories/pocketbase_drawer_navigation_repository.dart';
import '../data/repositories/pocketbase_featured_products_repository.dart';
import '../data/repositories/pocketbase_storefront_settings_repository.dart';
import '../data/repositories/product_foil_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/search_repository.dart';
import '../application/cms/cms_page_editor_repository.dart';
import '../application/cms/cms_page_repository.dart';
import '../application/cms/featured_products_repository.dart';

final apiBaseUrlProvider = Provider<String>((ref) => ApiConfig.apiBaseUrl);

final mediaBaseUrlProvider = Provider<String>((ref) => ApiConfig.mediaBaseUrl);

final pocketBaseClientProvider = Provider<PocketBaseClient>((ref) {
  return PocketBaseClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: ApiConfig.apiBaseUrl,
  );
});

final categoryCatalogRepositoryProvider = Provider<CategoryCatalogRepository>((
  ref,
) {
  return PocketBaseCategoryRepository(
    client: ref.watch(pocketBaseClientProvider),
  );
});

final productCatalogRepositoryProvider = Provider<ProductCatalogRepository>((
  ref,
) {
  return PocketBaseProductRepository(
    client: ref.watch(pocketBaseClientProvider),
  );
});

final productFoilRepositoryProvider = Provider<ProductFoilRepository>((ref) {
  return ProductFoilRepository(client: ref.watch(pocketBaseClientProvider));
});

final featuredProductsRepositoryProvider = Provider<FeaturedProductsRepository>(
  (ref) {
    return PocketBaseFeaturedProductsRepository(
      client: ref.watch(pocketBaseClientProvider),
    );
  },
);

final guestSessionStoreProvider = Provider<CartGuestSessionStore>((ref) {
  return GuestSessionStore();
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return PocketBaseCartRepository(
    client: ref.watch(pocketBaseClientProvider),
    guestIdProvider: () => ref.read(guestSessionStoreProvider).ensureGuestId(),
    useAddItemEndpoint: CartFeatureFlags.useCartAddEndpoint,
  );
});

final addToCartProvider = Provider<AddToCart>((ref) {
  return AddToCart(
    ref.watch(cartRepositoryProvider),
    ref.watch(guestSessionStoreProvider),
  );
});

final getActiveCartProvider = Provider<GetActiveCart>((ref) {
  return GetActiveCart(
    ref.watch(cartRepositoryProvider),
    ref.watch(guestSessionStoreProvider),
  );
});

final updateEntryQuantityProvider = Provider<UpdateEntryQuantity>((ref) {
  return UpdateEntryQuantity(ref.watch(cartRepositoryProvider));
});

final removeEntryProvider = Provider<RemoveEntry>((ref) {
  return RemoveEntry(ref.watch(cartRepositoryProvider));
});

final clearCartProvider = Provider<ClearCart>((ref) {
  return ClearCart(ref.watch(cartRepositoryProvider));
});

final drawerNavigationRepositoryProvider = Provider<DrawerNavigationRepository>(
  (ref) {
    return PocketBaseDrawerNavigationRepository(
      client: ref.watch(pocketBaseClientProvider),
    );
  },
);

final cmsPageRepositoryProvider = Provider<CmsPageRepository>((ref) {
  return PocketBaseCmsPageRepository(
    client: ref.watch(pocketBaseClientProvider),
  );
});

final cmsPageEditorRepositoryProvider = Provider<CmsPageEditorRepository>((
  ref,
) {
  return PocketBaseCmsPageEditorRepository(
    client: ref.watch(pocketBaseClientProvider),
  );
});

final storefrontSettingsRepositoryProvider =
    Provider<StorefrontSettingsRepository>((ref) {
      return PocketBaseStorefrontSettingsRepository(
        client: ref.watch(pocketBaseClientProvider),
      );
    });

final storefrontBrandSettingsProvider = FutureProvider<StorefrontBrandSettings>(
  (ref) {
    return ref.watch(storefrontSettingsRepositoryProvider).getBrandSettings();
  },
);

final storefrontNavigationSettingsProvider =
    FutureProvider<StorefrontNavigationSettings>((ref) {
      return ref
          .watch(storefrontSettingsRepositoryProvider)
          .getNavigationSettings();
    });

final getDefaultCategoryProvider = Provider<GetDefaultCategory>((ref) {
  return GetDefaultCategory(ref.watch(categoryCatalogRepositoryProvider));
});

final getActiveCategoriesProvider = Provider<GetActiveCategories>((ref) {
  return GetActiveCategories(ref.watch(categoryCatalogRepositoryProvider));
});

final getCategoryBySlugProvider = Provider<GetCategoryBySlug>((ref) {
  return GetCategoryBySlug(ref.watch(categoryCatalogRepositoryProvider));
});

final resolveProductRouteProvider = Provider<ResolveProductRoute>((ref) {
  return ResolveProductRoute(ref.watch(categoryCatalogRepositoryProvider));
});

final getCategoryProductsProvider = Provider<GetCategoryProducts>((ref) {
  return GetCategoryProducts(ref.watch(categoryCatalogRepositoryProvider));
});

final getProductDetailProvider = Provider<GetProductDetail>((ref) {
  return GetProductDetail(ref.watch(productCatalogRepositoryProvider));
});

final saveProductTextProvider = Provider<SaveProductText>((ref) {
  return SaveProductText(ref.watch(saveAdminRecordProvider));
});

final saveProductPriceProvider = Provider<SaveProductPrice>((ref) {
  return SaveProductPrice(
    ref.watch(saveAdminRecordProvider),
    ref.watch(adminBackofficeRepositoryProvider),
  );
});

final loadPdpLocalizedTextProvider = Provider<LoadPdpLocalizedText>((ref) {
  return LoadPdpLocalizedText(ref.watch(adminBackofficeRepositoryProvider));
});

final savePdpLocalizedTextProvider = Provider<SavePdpLocalizedText>((ref) {
  return SavePdpLocalizedText(ref.watch(adminBackofficeRepositoryProvider));
});

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return PocketBaseAdminAuthRepository(baseUrl: ApiConfig.apiBaseUrl);
});

final adminBackofficeRepositoryProvider = Provider<AdminBackofficeRepository>((
  ref,
) {
  return const PocketBaseAdminBackofficeRepository();
});

final adminMediaRepositoryProvider = Provider<AdminMediaRepository>((ref) {
  return PocketBaseAdminMediaRepository(baseUrl: ApiConfig.apiBaseUrl);
});

final authenticateAdminUserProvider = Provider<AuthenticateAdminUser>((ref) {
  return AuthenticateAdminUser(ref.watch(adminAuthRepositoryProvider));
});

final authenticateAdminSuperuserProvider = Provider<AuthenticateAdminSuperuser>(
  (ref) {
    return AuthenticateAdminSuperuser(
      ref.watch(adminBackofficeRepositoryProvider),
    );
  },
);

final loadAdminCollectionsProvider = Provider<LoadAdminCollections>((ref) {
  return LoadAdminCollections(ref.watch(adminBackofficeRepositoryProvider));
});

final saveAdminRecordProvider = Provider<SaveAdminRecord>((ref) {
  return SaveAdminRecord(ref.watch(adminBackofficeRepositoryProvider));
});

final deleteAdminRecordProvider = Provider<DeleteAdminRecord>((ref) {
  return DeleteAdminRecord(ref.watch(adminBackofficeRepositoryProvider));
});

final importCatalogCsvProvider = Provider<ImportCatalogCsv>((ref) {
  return ImportCatalogCsv(ref.watch(adminBackofficeRepositoryProvider));
});

final exportCatalogCsvProvider = Provider<ExportCatalogCsv>((ref) {
  return ExportCatalogCsv(ref.watch(adminBackofficeRepositoryProvider));
});

final replaceMediaAssetProvider = Provider<ReplaceMediaAsset>((ref) {
  return ReplaceMediaAsset(ref.watch(adminMediaRepositoryProvider));
});

final assignProductMediaProvider = Provider<AssignProductMedia>((ref) {
  return AssignProductMedia(ref.watch(adminBackofficeRepositoryProvider));
});

final addProductGalleryMediaProvider = Provider<AddProductGalleryMedia>((ref) {
  return AddProductGalleryMedia(ref.watch(adminBackofficeRepositoryProvider));
});

final replaceProductGalleryMediaProvider = Provider<ReplaceProductGalleryMedia>(
  (ref) {
    return ReplaceProductGalleryMedia(
      ref.watch(adminBackofficeRepositoryProvider),
    );
  },
);

final removeProductGalleryMediaProvider = Provider<RemoveProductGalleryMedia>((
  ref,
) {
  return RemoveProductGalleryMedia(
    ref.watch(adminBackofficeRepositoryProvider),
  );
});

final moveProductGalleryMediaProvider = Provider<MoveProductGalleryMedia>((
  ref,
) {
  return MoveProductGalleryMedia(ref.watch(adminBackofficeRepositoryProvider));
});

final setProductPrimaryMediaProvider = Provider<SetProductPrimaryMedia>((ref) {
  return SetProductPrimaryMedia(ref.watch(adminBackofficeRepositoryProvider));
});

final reorderCategoryProductsProvider = Provider<ReorderCategoryProducts>((
  ref,
) {
  return ReorderCategoryProducts(ref.watch(adminBackofficeRepositoryProvider));
});

final productSearchRepositoryProvider = Provider<ProductSearchRepository>((
  ref,
) {
  return PocketBaseSearchRepository(
    client: ref.watch(pocketBaseClientProvider),
  );
});

final searchProductsProvider = Provider<SearchProducts>((ref) {
  return SearchProducts(ref.watch(productSearchRepositoryProvider));
});

final loadNavigationEditorOptionsProvider =
    Provider<LoadNavigationEditorOptions>((ref) {
      return LoadNavigationEditorOptions(
        ref.watch(adminBackofficeRepositoryProvider),
      );
    });

final saveNavigationItemProvider = Provider<SaveNavigationItem>((ref) {
  return SaveNavigationItem(ref.watch(saveAdminRecordProvider));
});
