import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../app/catalog_routes.dart';
import '../../config/pdp_loading_quick_add_flags.dart';
import '../../core/utils/media_upload_guidance.dart';
import '../../core/utils/media_image_support.dart';
import '../../core/utils/price_utils.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/admin/add_product_gallery_media.dart';
import '../../application/catalog/save_product_price.dart';
import '../../core/utils/string_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_invalidator_provider.dart';
import '../providers/content_locale_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/pending_media_provider.dart';
import '../providers/pdp_loading_commerce_provider.dart';
import '../providers/product_providers.dart';
import '../performance/pdp_loading_performance_logger.dart';
import '../widgets/image_carousel.dart';
import '../widgets/cms/cms_admin_auth.dart';
import '../widgets/error_display.dart';
import '../widgets/hero_image_back_button.dart';
import '../widgets/media_picker_modal.dart';
import '../widgets/navigation/premium_shell_navbar.dart';
import '../widgets/navigation/sport_home_icon_loading_publisher.dart';
import '../widgets/photo_upload_dialog.dart';
import '../widgets/product_hero_tags.dart';
import '../widgets/pull_to_hero_back_detector.dart';
import '../widgets/cart_added_top_sheet.dart';
import '../widgets/pdp_atlas_image_exposure.dart';
import '../widgets/shared_app_bar.dart';
import '../widgets/storefront_category_drawer.dart';
import '../widgets/storefront_drawer_prefetch.dart';
import '../widgets/storefront_layout.dart';
import 'pdp/product_detail_cross_sells.dart';
import 'pdp/product_detail_footer.dart';
import 'pdp/product_detail_hero.dart';
import 'pdp/product_detail_hero_placeholder.dart';
import 'pdp/product_detail_info_tabs.dart';
import 'pdp/product_detail_loading_quick_add_section.dart';
import 'pdp/product_detail_mobile_purchase_surface.dart';
import 'pdp/product_detail_translations_sheet.dart';
import 'product_detail_layout_spec.dart';
import 'product_detail_narrative_logic.dart';

// Re-export the editor's semantics constants so existing tests that
// import them from product_detail_page.dart keep compiling.
export 'pdp/product_detail_inline_editors.dart'
    show
        kProductNameEditorSemanticsLabel,
        kProductNameEditorSemanticsIdentifier,
        kProductSummaryEditorSemanticsLabel,
        kProductSummaryEditorSemanticsIdentifier,
        kProductNameEditorInputKey;
export 'pdp/product_detail_translations_sheet.dart'
    show
        kPdpTranslationsEditorSemanticsLabel,
        kPdpTranslationsEditorSemanticsIdentifier;

// Re-export the loading-branch widgets (moved into pdp/) so existing tests
// that reference them via product_detail_page.dart keep compiling.
export 'pdp/product_detail_hero_placeholder.dart' show PdpHeroPlaceholder;
export 'pdp/product_detail_loading_quick_add_section.dart'
    show PdpLoadingQuickAddSection;

// ── Design tokens ──────────────────────────────────────────────
const kProductImageEditorSemanticsLabel =
    imageCarouselProductImageEditorSemanticsLabel;
const kProductImageEditorSemanticsIdentifier =
    imageCarouselProductImageEditorSemanticsIdentifier;
const kPdpImageBackButtonKey = kHeroImageBackButtonKey;
const _kPdpShellBg = Colors.white;

final _pdpCarouselScrollTargetMediaProvider = StateProvider.autoDispose
    .family<String?, String>((ref, productId) => null);

class ProductDetailPage extends ConsumerWidget {
  final String productId;
  final CatalogCategory? category;
  // Optional listing media carried over from the PLP card so the loading
  // branch can mount a Hero destination immediately (see _PdpHeroPlaceholder
  // and the loading branch of pdpAsync.when below). Omitted on deep-link
  // navigation, in which case the loading branch falls back to a spinner.
  final CatalogMedia? listingMediaHint;
  // Exact Hero tag worn by the source widget that pushed this PDP. When set,
  // both the loading-branch placeholder and the loaded-branch carousel reuse
  // it instead of the global product-id-only tag, so the flight pairs only
  // with that one source and back/forward transitions don't trigger ghost
  // Hero matches from unrelated cards still in the tree.
  final String? mainImageHeroTag;
  final bool animateSportHomeIconOnLoad;

  const ProductDetailPage({
    super.key,
    required this.productId,
    this.category,
    this.listingMediaHint,
    this.mainImageHeroTag,
    this.animateSportHomeIconOnLoad = false,
  });

  static const _heroBreadcrumbColor = Color.fromRGBO(123, 132, 135, 1);

  Future<void> _toggleEditMode(BuildContext context, WidgetRef ref) async {
    final isEditMode = ref.read(editModeProvider);
    if (isEditMode) {
      ref.read(editModeProvider.notifier).state = false;
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null) return;
    ref.read(editModeProvider.notifier).state = true;
  }

  Future<void> _handlePickPhoto(
    BuildContext context,
    WidgetRef ref,
    List<CatalogMedia> allMedia,
    int currentIndex,
  ) async {
    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final currentMedia = allMedia[currentIndex];
    final uploadResult = await PhotoUploadDialog.show(
      context,
      currentMedia: currentMedia,
      currentMediaId: currentMedia.id,
      authToken: authToken,
    );
    if (!context.mounted) return;

    if (uploadResult != null) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final container = ProviderScope.containerOf(context, listen: false);
      final pendingVersion = ref
          .read(pendingMediaProvider.notifier)
          .set(uploadResult.mediaId, uploadResult.optimized.fileBytes);
      unawaited(
        _backgroundUpload(
          scaffoldMessenger,
          container,
          productId,
          uploadResult,
          pendingVersion,
          currentMedia,
        ),
      );

      if (context.mounted) {
        final optimized = uploadResult.optimized;
        final message = optimized.wasOptimized
            ? 'Image mise à jour localement. Synchronisation en cours: ${formatBytesForHumans(optimized.originalBytes)} -> ${formatBytesForHumans(optimized.fileBytes.lengthInBytes)}'
            : 'Image mise à jour localement. Synchronisation en cours.';
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _backgroundUpload(
    ScaffoldMessengerState scaffoldMessenger,
    ProviderContainer container,
    String productId,
    PhotoPublishResult result,
    int pendingVersion,
    CatalogMedia replacedMedia,
  ) async {
    try {
      await container
          .read(replaceMediaAssetProvider)
          .uploadOnly(
            authToken: result.authToken,
            mediaId: result.mediaId,
            optimized: result.optimized,
            originalFileBytes: result.originalFileBytes,
            originalFilename: result.originalFilename,
            cropData: result.cropData,
          );

      await _evictReplacedMediaImageCache(replacedMedia);
      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForReplacedProductMedia(productId: productId),
          );
      final refreshedPdp = container.refresh(pdpProvider(productId).future);
      await refreshedPdp;
      container
          .read(pendingMediaProvider.notifier)
          .clear(result.mediaId, pendingVersion);
    } catch (error) {
      container
          .read(pendingMediaProvider.notifier)
          .clear(result.mediaId, pendingVersion);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text("Échec de la synchronisation de l'image: $error"),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _evictReplacedMediaImageCache(CatalogMedia media) async {
    final urls = <String>{
      media.url,
      media.previewUrl,
      if (media.originalUrl?.trim().isNotEmpty == true) media.originalUrl!,
      media.listingUrl,
      media.galleryThumbnailUrl,
      media.productDetailMobileUrl,
      media.productDetailTabletUrl,
      media.productDetailDesktopUrl,
    }.where((url) => url.trim().isNotEmpty).toList(growable: false);

    await Future.wait([
      for (final url in urls) CachedNetworkImage.evictFromCache(url),
    ]);
  }

  Future<void> _handlePickMedia(
    BuildContext context,
    WidgetRef ref,
    CatalogMedia? currentMedia,
  ) async {
    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final initialSelection = currentMedia == null
        ? null
        : MediaPickerInitialSelection(
            mediaId: currentMedia.id,
            previewUrl: currentMedia.previewUrl,
            title: currentMedia.title,
            altText: currentMedia.altText,
          );

    final result = await MediaPickerModal.show(
      context,
      authToken: authToken,
      currentMediaId: currentMedia?.id,
      initialSelection: initialSelection,
    );
    if (result == null || !context.mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await container
          .read(assignProductMediaProvider)
          .call(
            authToken: authToken,
            productId: productId,
            mediaId: result.mediaId,
          );

      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForAssignedProductMedia(productId: productId),
          );

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Image principale mise à jour.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d\'image: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleAddGalleryMedia(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
  ) async {
    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final result = await MediaPickerModal.show(context, authToken: authToken);
    if (result == null || !context.mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await container
          .read(addProductGalleryMediaProvider)
          .call(
            authToken: authToken,
            productId: product.id,
            mediaId: result.mediaId,
          );

      ref
              .read(_pdpCarouselScrollTargetMediaProvider(product.id).notifier)
              .state =
          result.mediaId;
      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForAddedProductGalleryMedia(productId: product.id),
          );
      final refreshedPdp = container.refresh(pdpProvider(product.id).future);
      await refreshedPdp;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Image ajoutée au carousel.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'ajout au carousel: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleReplaceCarouselMedia(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
    List<CatalogMedia> mediaItems,
    int currentIndex,
  ) async {
    if (currentIndex < 0 || currentIndex >= mediaItems.length) {
      return;
    }

    final currentMedia = mediaItems[currentIndex];
    if (_isProductMainOrFallbackImage(product, currentMedia)) {
      await _handlePickMedia(context, ref, currentMedia);
      return;
    }

    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final result = await MediaPickerModal.show(
      context,
      authToken: authToken,
      currentMediaId: currentMedia.id,
      initialSelection: MediaPickerInitialSelection(
        mediaId: currentMedia.id,
        previewUrl: currentMedia.previewUrl,
        title: currentMedia.title,
        altText: currentMedia.altText,
      ),
    );
    if (result == null || !context.mounted) return;

    final container = ProviderScope.containerOf(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await container
          .read(replaceProductGalleryMediaProvider)
          .call(
            authToken: authToken,
            productId: product.id,
            currentMediaId: currentMedia.id,
            replacementMediaId: result.mediaId,
          );

      ref
              .read(_pdpCarouselScrollTargetMediaProvider(product.id).notifier)
              .state =
          result.mediaId;
      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForAddedProductGalleryMedia(productId: product.id),
          );
      final refreshedPdp = container.refresh(pdpProvider(product.id).future);
      await refreshedPdp;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Image du carousel mise à jour.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du remplacement de l\'image: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleRemoveCarouselMedia(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
    List<CatalogMedia> mediaItems,
    int currentIndex,
  ) async {
    if (currentIndex < 0 || currentIndex >= mediaItems.length) {
      return;
    }

    final currentMedia = mediaItems[currentIndex];
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_isProductMainOrFallbackImage(product, currentMedia)) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'L’image principale ne peut pas être supprimée ici. Remplacez-la par une autre image.',
          ),
        ),
      );
      return;
    }

    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’image du carousel'),
        content: const Text(
          'Cette action retire l’image de la galerie du produit, sans supprimer le média de la bibliothèque.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final container = ProviderScope.containerOf(context, listen: false);

    try {
      await container
          .read(removeProductGalleryMediaProvider)
          .call(
            authToken: authToken,
            productId: product.id,
            mediaId: currentMedia.id,
          );

      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForAddedProductGalleryMedia(productId: product.id),
          );
      final refreshedPdp = container.refresh(pdpProvider(product.id).future);
      await refreshedPdp;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Image retirée du carousel.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression de l\'image: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleSetCarouselFirstMedia(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
    List<CatalogMedia> mediaItems,
    int currentIndex,
  ) async {
    if (currentIndex <= 0 || currentIndex >= mediaItems.length) {
      return;
    }

    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final selectedMedia = mediaItems[currentIndex];
    final container = ProviderScope.containerOf(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await container
          .read(setProductPrimaryMediaProvider)
          .call(
            authToken: authToken,
            productId: product.id,
            mediaId: selectedMedia.id,
          );

      ref
              .read(_pdpCarouselScrollTargetMediaProvider(product.id).notifier)
              .state =
          selectedMedia.id;
      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForAssignedProductMedia(productId: product.id),
          );
      final refreshedPdp = container.refresh(pdpProvider(product.id).future);
      await refreshedPdp;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Image affichée en premier sur la PDP.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d\'ordre: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleMoveCarouselMedia(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
    List<CatalogMedia> mediaItems,
    int currentIndex,
    int targetIndex,
  ) async {
    if (currentIndex < 0 ||
        currentIndex >= mediaItems.length ||
        targetIndex < 0 ||
        targetIndex >= mediaItems.length ||
        currentIndex == targetIndex) {
      return;
    }

    if (targetIndex == 0) {
      await _handleSetCarouselFirstMedia(
        context,
        ref,
        product,
        mediaItems,
        currentIndex,
      );
      return;
    }

    if (currentIndex == 0) {
      await _handleSetCarouselFirstMedia(
        context,
        ref,
        product,
        mediaItems,
        targetIndex,
      );
      return;
    }

    final currentMedia = mediaItems[currentIndex];
    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) return;
    if (!context.mounted) return;

    final direction = targetIndex < currentIndex
        ? ProductGalleryMoveDirection.previous
        : ProductGalleryMoveDirection.next;
    final container = ProviderScope.containerOf(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await container
          .read(moveProductGalleryMediaProvider)
          .call(
            authToken: authToken,
            productId: product.id,
            mediaId: currentMedia.id,
            direction: direction,
          );

      ref
              .read(_pdpCarouselScrollTargetMediaProvider(product.id).notifier)
              .state =
          currentMedia.id;
      container
          .read(catalogInvalidatorProvider)
          .applyToContainer(
            container,
            invalidationsForAddedProductGalleryMedia(productId: product.id),
          );
      final refreshedPdp = container.refresh(pdpProvider(product.id).future);
      await refreshedPdp;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Ordre des images mis à jour.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d\'ordre: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  bool _isProductMainOrFallbackImage(
    CatalogProduct product,
    CatalogMedia media,
  ) {
    if (product.picture?.id == media.id) {
      return true;
    }
    return product.picture == null &&
        product.gallery.isEmpty &&
        product.thumbnail?.id == media.id;
  }

  Future<bool> _saveProductPrice(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
    CatalogPrice? priceRow,
    double price,
  ) async {
    final authToken = ref.read(adminAuthTokenProvider);
    if (authToken == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion admin requise pour modifier ce contenu.'),
          ),
        );
      }
      return false;
    }

    final result = await ref.read(saveProductPriceProvider)(
      baseUrl: ref.read(apiBaseUrlProvider),
      authToken: authToken,
      productId: product.id,
      priceRow: priceRow,
      price: price,
    );

    switch (result) {
      case SaveProductPriceNoChange():
        return true;
      case SaveProductPriceSaved():
        ref
            .read(catalogInvalidatorProvider)
            .applyFromWidget(
              ref,
              invalidationsForSavedProductPrice(product.id),
            );
        final refreshedPdp = ref.refresh(pdpProvider(product.id).future);
        await refreshedPdp;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prix produit mis à jour.')),
          );
        }
        return true;
      case SaveProductPriceFailure(:final error):
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la mise à jour du prix: $error'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return false;
    }
  }

  Future<void> _handleEditTranslations(
    BuildContext context,
    WidgetRef ref,
    CatalogProduct product,
  ) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;

    final changed = await PdpTranslationsEditorSheet.show(
      context,
      productId: product.id,
      authToken: token,
      initialLocale: ref.read(contentLocaleProvider),
    );
    if (changed != true) return;

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(ref, invalidationsForSavedProductText(product.id));
    final refreshedPdp = ref.refresh(pdpProvider(product.id).future);
    await refreshedPdp;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Traductions PDP mises à jour.')),
      );
    }
  }

  List<CatalogMedia> _buildAllMedia(CatalogProduct product) {
    final allMedia = <CatalogMedia>[];
    final seenMediaIds = <String>{};
    void addMedia(CatalogMedia? media) {
      if (media == null || !seenMediaIds.add(media.id)) {
        return;
      }
      allMedia.add(media);
    }

    if (product.picture != null) {
      addMedia(product.picture);
    }
    for (final media in product.gallery) {
      addMedia(media);
    }
    if (allMedia.isEmpty && product.thumbnail != null) {
      addMedia(product.thumbnail);
    }
    return allMedia;
  }

  /// Adds [product] to the cart, awaiting the server. Resolves to `true` on
  /// success (and opens the cart-added top sheet), `false` on any failure.
  /// Failures are surfaced inside the purchase bar, not via a SnackBar.
  Future<bool> _addToCart(
    BuildContext context,
    WidgetRef ref, {
    required CatalogProduct product,
    required CatalogPrice? defaultPrice,
    required String symbol,
    int quantity = 1,
  }) async {
    if (defaultPrice == null) {
      return false;
    }

    try {
      await ref
          .read(cartControllerProvider.notifier)
          .addProduct(
            product: product,
            price: defaultPrice,
            quantity: quantity,
          );
    } catch (_) {
      return false;
    }

    if (!context.mounted) {
      return true;
    }

    ref.read(cartTopSheetOpenProvider.notifier).state = true;
    unawaited(
      showCartAddedTopSheet(
        context: context,
        product: product,
        defaultPrice: defaultPrice,
        symbol: symbol,
        quantity: quantity,
        // Land on the cart review page (`/cart`) so the user sees the
        // summary first; the "Commander" CTA there pushes the real
        // funnel (`/checkout` → redirect → `/checkout/access`).
        onCheckout: () => context.push(CatalogRoutes.cart),
      ).whenComplete(() {
        if (context.mounted) {
          ref.read(cartTopSheetOpenProvider.notifier).state = false;
          ref.read(cartBackgroundSyncErrorProvider.notifier).state = null;
        }
      }),
    );
    return true;
  }

  Widget _buildPageScaffold({
    required BuildContext context,
    required Widget body,
    Widget? bottomNavigationBar,
  }) {
    return StorefrontDrawerPrefetch(
      child: Scaffold(
        backgroundColor: _kPdpShellBg,
        drawer: StorefrontCategoryDrawer(currentCategoryId: category?.id),
        floatingActionButton: _PdpEditFab(onPressed: _toggleEditMode),
        bottomNavigationBar: bottomNavigationBar,
        body: body,
      ),
    );
  }

  Widget _buildHeroBreadcrumbOverlay({
    required BuildContext context,
    required CatalogProduct product,
    required bool reserveBackButtonSpace,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isMobile = !isTablet && !isDesktop;
    if (category == null) {
      return const SizedBox.shrink();
    }

    if (isMobile) {
      final label = Text(
        category!.name,
        style: const TextStyle(
          color: _heroBreadcrumbColor,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.1,
        ),
      );
      if (!reserveBackButtonSpace) {
        return label;
      }
      return Padding(
        padding: const EdgeInsets.only(top: kHeroImageBackButtonSize + 12),
        child: label,
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 520 : (isTablet ? 460 : 320),
        ),
        child: SharedInlineBreadcrumb(
          items: [
            SharedBreadcrumbItem(
              label: category!.name,
              routeName: CatalogRoutes.categoryLocation(category!),
            ),
          ],
          fontSize: isDesktop ? 14 : (isTablet ? 13.5 : 13),
          underlineLinks: false,
          linkColor: _heroBreadcrumbColor,
          currentColor: _heroBreadcrumbColor,
          separatorColor: _heroBreadcrumbColor,
        ),
      ),
    );
  }

  PdpAtlasImageExposureData _buildPdpAtlasImageExposureData({
    required CatalogProduct product,
    required CatalogMedia currentImage,
    required String? categoryName,
    required String? summary,
  }) {
    final productName = product.name.trim();
    final mediaAlt = currentImage.altText?.trim();
    final mediaTitle = currentImage.title?.trim();
    final resolvedAlt = (mediaAlt != null && mediaAlt.isNotEmpty)
        ? mediaAlt
        : (mediaTitle != null && mediaTitle.isNotEmpty)
        ? mediaTitle
        : (productName.isNotEmpty ? productName : 'product image');
    final resolvedImageUrl = currentImage.originalUrl?.trim().isNotEmpty == true
        ? currentImage.originalUrl!.trim()
        : currentImage.url.trim();

    return PdpAtlasImageExposureData(
      productId: product.id,
      productCode: product.code.trim(),
      productName: productName.isNotEmpty ? productName : product.code.trim(),
      categoryName: categoryName?.trim().isEmpty ?? true
          ? null
          : categoryName?.trim(),
      imageUrl: resolvedImageUrl,
      imageAlt: resolvedAlt,
      mediaTitle: mediaTitle?.isEmpty ?? true ? null : mediaTitle,
      summary: summary?.trim().isEmpty ?? true ? null : summary?.trim(),
    );
  }

  void _openPdpAtlasImageVisionModal({
    required CatalogProduct product,
    required CatalogMedia currentImage,
    required String? categoryName,
    required String? summary,
  }) {
    showPdpAtlasImageVisionModal(
      _buildPdpAtlasImageExposureData(
        product: product,
        currentImage: currentImage,
        categoryName: categoryName,
        summary: summary,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CartBackgroundSyncError?>(cartBackgroundSyncErrorProvider, (
      previous,
      next,
    ) {
      if (next == null || previous?.id == next.id || !context.mounted) {
        return;
      }
      if (ref.read(cartTopSheetOpenProvider)) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pdpCartAddedSyncFailed)),
      );
    });
    final pdpAsync = ref.watch(pdpProvider(productId));
    final isEditMode = ref.watch(editModeProvider);
    final width = MediaQuery.sizeOf(context).width;
    final layout = ProductDetailLayoutSpec.forWidth(width);
    final scrollStorageKey = PageStorageKey<String>('pdp-scroll-$productId');

    final isInitialPdpLoading =
        animateSportHomeIconOnLoad && pdpAsync.isLoading && !pdpAsync.hasValue;
    final page = pdpAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () {
        final hintMedia = listingMediaHint;
        final canRenderPlaceholderHero =
            hintMedia != null &&
            !isEditMode &&
            !MediaQuery.disableAnimationsOf(context) &&
            !isKnownUnsupportedImageFormat(url: hintMedia.listingUrl);

        // Mount a placeholder Hero on frame one of the loading branch so
        // Flutter's Navigator scan finds a destination tag during push and
        // the PLP→PDP shared-element flight actually starts. Without this
        // the destination is just a spinner, the scan misses the pair, and
        // no flight happens (user sees only the default route transition).
        //
        // Mutual exclusion: this placeholder Hero is mounted ONLY while
        // pdpAsync is loading. Once data resolves the carousel Hero takes
        // over in the data branch with the same tag, so the two never
        // coexist in the tree → no duplicate-tag error.
        //
        // Narrative caveat: hasNarrative is only known after data. If the
        // resolved product is narrative, mainImageHeroTag in the data
        // branch is null (see below) so the placeholder Hero will simply
        // unpair on swap — Flutter handles unpaired Heroes gracefully.
        // Accepted trade-off for the dominant standard-PDP case.
        final loadingSnapshotProvider = pdpLoadingCommerceSnapshotProvider(
          productId,
        );
        final loadingSnapshot = ref.exists(loadingSnapshotProvider)
            ? ref.watch(loadingSnapshotProvider)
            : null;
        final loadingProduct = loadingSnapshot?.product.id == productId
            ? loadingSnapshot?.product
            : null;
        final loadingQuickAdd = canRenderPlaceholderHero
            ? _buildLoadingQuickAdd(context, ref, layout: layout)
            : null;
        final canShowImageBackOverlay =
            layout.isMobile && canRenderPlaceholderHero;
        final body = canRenderPlaceholderHero
            ? buildPdpLoadingHeroScaffoldBody(
                productId: productId,
                imageHeroTag: mainImageHeroTag,
                listingMedia: hintMedia,
                layout: layout,
                loadingQuickAdd: loadingQuickAdd,
                loadingProduct: loadingProduct,
                scrollKey: scrollStorageKey,
              )
            : _buildPullableLoadingFallback(scrollKey: scrollStorageKey);
        final bodyWithBackOverlay = _buildMobileImageBackOverlay(
          context: context,
          layout: layout,
          enabled: canShowImageBackOverlay,
          triggerBubblePop: false,
          child: body,
        );

        return _buildPageScaffold(
          context: context,
          body: _wrapPullToHeroBack(
            context: context,
            child: bodyWithBackOverlay,
          ),
        );
      },
      error: (error, _) => _buildPageScaffold(
        context: context,
        body: ErrorDisplay(
          error: error,
          onRetry: () => ref.invalidate(pdpProvider(productId)),
        ),
      ),
      data: (pdpState) {
        _schedulePdpDataReadyLog(ref);

        final allMedia = _buildAllMedia(pdpState.product);
        final narrativeMedia = dedupeCatalogMediaById(allMedia);
        final hasNarrative = shouldEnableNarrative(
          uniqueMedia: narrativeMedia,
          chapters: pdpState.chapters,
        );

        return _buildPageScaffold(
          context: context,
          body: _AnchorKeyScope(
            builder: (purchaseAnchorKey) => _PdpCartPrefetcher(
              productId: productId,
              // Scope the per-media pending-upload watch to this Consumer so a
              // pending-media change (admin image upload) rebuilds only the
              // content subtree — not the whole page, which would otherwise
              // re-watch pdpProvider, re-register the cart listener, and
              // recompute allMedia/narrative state.
              child: Consumer(
                builder: (context, contentRef, _) {
                  final pendingMedia = _watchPendingMediaFor(
                    contentRef,
                    allMedia,
                  );
                  return _buildContent(
                    context,
                    contentRef,
                    pdpState,
                    isEditMode,
                    pendingMedia,
                    layout: layout,
                    allMedia: allMedia,
                    narrativeMedia: narrativeMedia,
                    hasNarrative: hasNarrative,
                    purchaseAnchorKey: purchaseAnchorKey,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    if (!animateSportHomeIconOnLoad) {
      return page;
    }
    return SportHomeIconLoadingPublisher(
      isLoading: isInitialPdpLoading,
      child: page,
    );
  }

  Map<String, PendingMediaEntry> _watchPendingMediaFor(
    WidgetRef ref,
    List<CatalogMedia> mediaItems,
  ) {
    final entries = <String, PendingMediaEntry>{};
    for (final media in mediaItems) {
      final pending = ref.watch(pendingMediaForProvider(media.id));
      if (pending != null) {
        entries[media.id] = pending;
      }
    }
    return entries;
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProductDetailData pdpState,
    bool isEditMode,
    Map<String, PendingMediaEntry> pendingMedia, {
    required ProductDetailLayoutSpec layout,
    required List<CatalogMedia> allMedia,
    required List<CatalogMedia> narrativeMedia,
    required bool hasNarrative,
    required GlobalKey purchaseAnchorKey,
  }) {
    final product = pdpState.product;
    final prices = pdpState.prices;
    final defaultPrice = getDefaultPrice(prices);
    final originalPrice = getOriginalPrice(prices);
    final discount = computeDiscount(defaultPrice, originalPrice);
    final symbol = defaultPrice?.currencySymbol ?? '€';
    final hasVariantSelector = _hasVariantSelector(pdpState);
    final isNew = isNewProduct(product.onlineDate);
    final visibleSummary = stripHtml(product.summary ?? '');
    final narrativeMediaIds = narrativeMedia.map((media) => media.id).toSet();
    final carouselScrollTargetMediaId = ref.watch(
      _pdpCarouselScrollTargetMediaProvider(product.id),
    );
    final canShowImageBackOverlay = layout.isMobile;
    final chaptersByMediaId = {
      for (final chapter in pdpState.chapters)
        if (narrativeMediaIds.contains(chapter.mediaId))
          chapter.mediaId: chapter,
    };
    final scrollStorageKey = PageStorageKey<String>('pdp-scroll-${product.id}');
    final heroBreadcrumbOverlay = _buildHeroBreadcrumbOverlay(
      context: context,
      product: product,
      reserveBackButtonSpace: canShowImageBackOverlay,
    );
    final detailTabs = ProductDetailInfoTabs(
      product: product,
      layout: layout,
      visibleSummary: visibleSummary,
      isEditMode: isEditMode,
    );
    final mobilePurchaseAnchorKey = layout.isMobile && !hasNarrative
        ? purchaseAnchorKey
        : null;
    // Narrative PDPs have scroll/page-driven image state, so Hero support is
    // intentionally scoped to standard PDP bodies in V1.
    //
    // When the route hint provided a source-scoped Hero tag, reuse it so the
    // flight pairs with the exact source that pushed this PDP. Without a
    // hint (deep link, breadcrumb nav, etc.) we still mount a Hero with the
    // global product-id-only tag — there is no source to compete with, and
    // a tagged carousel keeps pull-to-hero-back functional on pop.
    final resolvedMainImageHeroTag =
        !hasNarrative &&
            !isEditMode &&
            !MediaQuery.disableAnimationsOf(context) &&
            allMedia.isNotEmpty &&
            !isKnownUnsupportedImageFormat(url: allMedia.first.url)
        ? (mainImageHeroTag ?? productImageHeroTag(product.id))
        : null;

    final heroContext = PdpHeroContext(
      product: product,
      layout: layout,
      pendingMedia: pendingMedia,
      isEditMode: isEditMode,
      allMedia: allMedia,
      defaultPrice: defaultPrice,
      originalPrice: originalPrice,
      discount: discount,
      symbol: symbol,
      isNew: isNew,
      hasVariantSelector: hasVariantSelector,
      heroBreadcrumbOverlay: heroBreadcrumbOverlay,
      detailTabs: detailTabs,
      mobilePurchaseAnchorKey: mobilePurchaseAnchorKey,
      onPickPhoto: (media, index) =>
          _handlePickPhoto(context, ref, media, index),
      onPickMedia: (media, index) =>
          _handleReplaceCarouselMedia(context, ref, product, media, index),
      onRemoveMedia: (media, index) =>
          _handleRemoveCarouselMedia(context, ref, product, media, index),
      onMoveMedia: (media, currentIndex, targetIndex) =>
          _handleMoveCarouselMedia(
            context,
            ref,
            product,
            media,
            currentIndex,
            targetIndex,
          ),
      onSetFirstMedia: (media, index) =>
          _handleSetCarouselFirstMedia(context, ref, product, media, index),
      onAddMedia: () => _handleAddGalleryMedia(context, ref, product),
      carouselScrollTargetMediaId: carouselScrollTargetMediaId,
      onCarouselScrollTargetHandled: (mediaId) {
        final provider = _pdpCarouselScrollTargetMediaProvider(product.id);
        if (ref.read(provider) == mediaId) {
          ref.read(provider.notifier).state = null;
        }
      },
      onEditTranslations: () => _handleEditTranslations(context, ref, product),
      onSavePrice: (value) =>
          _saveProductPrice(context, ref, product, defaultPrice, value),
      onAddToCart: () => _addToCart(
        context,
        ref,
        product: product,
        defaultPrice: defaultPrice,
        symbol: symbol,
      ),
      onOpenVisionModal: kIsWeb
          ? (currentImage) => _openPdpAtlasImageVisionModal(
              product: product,
              currentImage: currentImage,
              categoryName: category?.name,
              summary: visibleSummary,
            )
          : null,
      mainImageHeroTag: resolvedMainImageHeroTag,
    );

    final Widget heroBody;
    if (hasNarrative) {
      heroBody = NarrativeHeroBody(
        heroContext: heroContext,
        narrativeMedia: narrativeMedia,
        chaptersByMediaId: chaptersByMediaId,
      );
    } else if (layout.isDesktop) {
      heroBody = DesktopHeroBody(heroContext: heroContext);
    } else if (layout.isSplit) {
      heroBody = SplitHeroBody(heroContext: heroContext);
    } else {
      heroBody = MobileHeroBody(heroContext: heroContext);
    }

    final heroSectionChild = layout.isWide
        ? StorefrontFullBleed(child: heroBody)
        : heroBody;
    Widget buildScrollView({ScrollController? controller}) {
      return CustomScrollView(
        key: scrollStorageKey,
        controller: controller,
        slivers: [
          SliverToBoxAdapter(
            child: StorefrontPageSection(
              maxWidth: layout.maxWidth,
              minHorizontalPadding: layout.horizontalPadding,
              padding: EdgeInsets.only(
                top: layout.heroTopPadding,
                bottom: layout.isMobile ? 40 : 56,
              ),
              child: heroSectionChild,
            ),
          ),
          if (layout.isMobile || layout.isDesktop)
            SliverToBoxAdapter(
              child: ProductDetailCrossSellArea(
                categoryId: category?.id,
                currentProductId: product.id,
                currentMainImageHeroTag: resolvedMainImageHeroTag,
              ),
            ),
          if (layout.isDesktop)
            const SliverToBoxAdapter(child: ProductDetailFooter())
          else
            SliverToBoxAdapter(
              child: SizedBox(height: layout.isMobile ? 104 : 72),
            ),
        ],
      );
    }

    final purchaseScrollView = mobilePurchaseAnchorKey == null
        ? buildScrollView()
        : MobilePdpPurchaseSurface(
            anchorKey: mobilePurchaseAnchorKey,
            defaultPrice: defaultPrice,
            symbol: symbol,
            onAddToCart: () => _addToCart(
              context,
              ref,
              product: product,
              defaultPrice: defaultPrice,
              symbol: symbol,
            ),
            scrollBuilder: (controller) =>
                buildScrollView(controller: controller),
          );

    return Stack(
      children: [
        _buildMobileImageBackOverlay(
          context: context,
          layout: layout,
          enabled: canShowImageBackOverlay,
          triggerBubblePop: true,
          child: _wrapPullToHeroBack(
            context: context,
            child: purchaseScrollView,
          ),
        ),
        PdpAtlasImageExposure(enabled: isEditMode && kIsWeb),
      ],
    );
  }

  Widget _wrapPullToHeroBack({
    required BuildContext context,
    required Widget child,
  }) {
    return PullToHeroBackDetector(
      onTrigger: () => _handlePullToHeroBack(context),
      child: child,
    );
  }

  Widget _buildMobileImageBackOverlay({
    required BuildContext context,
    required ProductDetailLayoutSpec layout,
    required bool enabled,
    required bool triggerBubblePop,
    required Widget child,
  }) {
    if (!enabled || !layout.isMobile) {
      return child;
    }
    return _MobilePdpImageBackOverlay(
      layout: layout,
      onBack: () => _handleExplicitPdpBack(context),
      triggerBubblePop: triggerBubblePop,
      child: child,
    );
  }

  // A scrollable spinner so the loading fallback (deep-link / no hint media /
  // unsupported format) still emits ScrollNotifications and can be pulled back.
  // The pop itself is gated by _handlePullToHeroBack (canPop), so deep links
  // with no previous route stay put.
  Widget _buildPullableLoadingFallback({Key? scrollKey}) {
    return CustomScrollView(
      key: scrollKey,
      physics: AlwaysScrollableScrollPhysics(),
      slivers: const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  /// Pops back to the PLP from the pull-down gesture, letting the shared Hero
  /// fly the product image back. This never
  /// falls back to `context.go(...)`: a direct deep-link open (nothing to pop)
  /// must stay put rather than navigate somewhere unexpected.
  void _handlePullToHeroBack(BuildContext context) {
    if (!_canNavigateBack(context)) return;

    // Don't pop while a route transition / Hero flight is still settling.
    final route = ModalRoute.of(context);
    if (route != null &&
        (!route.isCurrent ||
            route.animation?.status != AnimationStatus.completed)) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      unawaited(navigator.maybePop());
      return;
    }
    context.pop();
  }

  void _handleExplicitPdpBack(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null &&
        (!route.isCurrent ||
            route.animation?.status != AnimationStatus.completed)) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      unawaited(navigator.maybePop());
      return;
    }

    try {
      context.pop();
    } catch (_) {
      // Direct deep links have no route to pop. Keep the PDP in place instead
      // of inventing a category fallback that might be wrong.
    }
  }

  bool _canNavigateBack(BuildContext context) {
    return Navigator.of(context).canPop() || context.canPop();
  }

  bool _hasVariantSelector(ProductDetailData pdpState) {
    // Product variants are not part of ProductDetailData yet.
    return false;
  }

  Widget? _buildLoadingQuickAdd(
    BuildContext context,
    WidgetRef ref, {
    required ProductDetailLayoutSpec layout,
  }) {
    if (!ref.watch(pdpLoadingQuickAddEnabledProvider) ||
        !ref.watch(pdpLoadingQuickAddServerValidationProvider)) {
      return null;
    }

    final snapshot = ref.watch(pdpLoadingCommerceSnapshotProvider(productId));
    if (snapshot == null || snapshot.product.id != productId) {
      return null;
    }
    if (snapshot.hasVariantSelector ||
        !snapshot.isFresh(ref.watch(cacheClockProvider)())) {
      return null;
    }

    final defaultPrice = getDefaultPrice(snapshot.prices);
    final currencyCode = defaultPrice?.currencyCode?.trim();
    if (defaultPrice == null ||
        defaultPrice.id.trim().isEmpty ||
        currencyCode == null ||
        currencyCode.isEmpty) {
      return null;
    }

    return PdpLoadingQuickAddSection(
      layout: layout,
      defaultPrice: defaultPrice,
      symbol: defaultPrice.currencySymbol ?? '€',
      onAddToCart: () => _addToCart(
        context,
        ref,
        product: snapshot.product,
        defaultPrice: defaultPrice,
        symbol: defaultPrice.currencySymbol ?? '€',
      ),
    );
  }

  void _schedulePdpDataReadyLog(WidgetRef ref) {
    if (ref.read(pdpLoadingTapTraceProvider(productId)) == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trace = ref.read(pdpLoadingTapTraceProvider(productId));
      if (trace == null) {
        return;
      }
      ref.read(pdpLoadingTapTraceProvider(productId).notifier).state = null;
      final now = ref.read(cacheClockProvider)();
      ref
          .read(pdpLoadingPerformanceLoggerProvider)
          .dataReady(
            productId: productId,
            latency: now.difference(trace.tappedAt),
            heroEligible: trace.heroEligible,
          );
    });
  }
}

class _MobilePdpImageBackOverlay extends StatefulWidget {
  final ProductDetailLayoutSpec layout;
  final VoidCallback onBack;
  final bool triggerBubblePop;
  final Widget child;

  const _MobilePdpImageBackOverlay({
    required this.layout,
    required this.onBack,
    required this.triggerBubblePop,
    required this.child,
  });

  @override
  State<_MobilePdpImageBackOverlay> createState() =>
      _MobilePdpImageBackOverlayState();
}

class _MobilePdpImageBackOverlayState
    extends State<_MobilePdpImageBackOverlay> {
  double _scrollPixels = 0;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final nextPixels = notification.metrics.pixels
        .clamp(0.0, double.infinity)
        .toDouble();
    if ((nextPixels - _scrollPixels).abs() < 0.5) {
      return false;
    }
    setState(() => _scrollPixels = nextPixels);
    return false;
  }

  double _buttonTop(BuildContext context) {
    final shellNavbarMetrics = PremiumShellNavbarMetrics.maybeOf(context);
    if (shellNavbarMetrics?.isVisible == true) {
      return kHeroImageBackButtonTopGap;
    }
    return MediaQuery.paddingOf(context).top + kHeroImageBackButtonTopGap;
  }

  @override
  Widget build(BuildContext context) {
    final top = _buttonTop(context);
    final imageHeight =
        MediaQuery.sizeOf(context).width / widget.layout.heroAspectRatio;
    final visibleUntilScroll = math.max(
      0.0,
      imageHeight - top - kHeroImageBackButtonSize,
    );
    final isVisible = _scrollPixels <= visibleUntilScroll;

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: widget.child,
        ),
        Positioned(
          top: top,
          left: kHeroImageBackButtonLeftGap,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              opacity: isVisible ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: HeroImageBackButton(
                buttonKey: kPdpImageBackButtonKey,
                onPressed: widget.onBack,
                triggerBubblePop: widget.triggerBubblePop,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Owns a single [GlobalKey] for the mobile purchase anchor, created once per
/// mounted page element. Allocating the key inside `build` instead would mint a
/// fresh key on every rebuild (edit toggle, resize, pending-media, cart events),
/// tearing down and remounting the keyed purchase surface each time.
class _AnchorKeyScope extends StatefulWidget {
  final Widget Function(GlobalKey anchorKey) builder;

  const _AnchorKeyScope({required this.builder});

  @override
  State<_AnchorKeyScope> createState() => _AnchorKeyScopeState();
}

class _AnchorKeyScopeState extends State<_AnchorKeyScope> {
  final GlobalKey _anchorKey = GlobalKey(
    debugLabel: 'mobile-pdp-purchase-anchor',
  );

  @override
  Widget build(BuildContext context) => widget.builder(_anchorKey);
}

class _PdpCartPrefetcher extends ConsumerStatefulWidget {
  final String productId;
  final Widget child;

  const _PdpCartPrefetcher({required this.productId, required this.child});

  @override
  ConsumerState<_PdpCartPrefetcher> createState() => _PdpCartPrefetcherState();
}

class _PdpCartPrefetcherState extends ConsumerState<_PdpCartPrefetcher> {
  bool _scheduled = false;

  @override
  void didUpdateWidget(covariant _PdpCartPrefetcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _scheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          ref.read(cartControllerProvider.notifier).prefetchActiveCart(),
        );
      });
    }

    return widget.child;
  }
}

class _PdpEditFab extends ConsumerWidget {
  final Future<void> Function(BuildContext context, WidgetRef ref) onPressed;

  const _PdpEditFab({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(editControlsVisibleProvider);
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final isEditMode = ref.watch(editModeProvider);
    return FloatingActionButton.small(
      onPressed: () => unawaited(onPressed(context, ref)),
      backgroundColor: isEditMode
          ? const Color(0xFFA8892E)
          : const Color(0xFF2B2B2B),
      child: Icon(
        isEditMode ? Icons.close : Icons.edit,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

/// Mirrors the data-branch outer chrome (CustomScrollView →
/// SliverToBoxAdapter → StorefrontPageSection → StorefrontFullBleed in wide
/// layouts) so the placeholder Hero rect equals the rect the eventual
/// carousel will occupy. Without this the Hero would land in a slightly
/// different position and the user would see a jump when data resolves.
