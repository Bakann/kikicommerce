import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/catalog_routes.dart';
import '../../app/locale_route_resolver.dart';
import '../../application/cms/cms_models.dart';
import '../../application/cms/cms_page_repository.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/catalog/plp_parent_routing.dart';
import '../../application/admin/reorder_category_products.dart';
import '../../application/storefront/storefront_plp_profile.dart';
import '../../application/storefront/storefront_theme.dart';
import '../../core/constants.dart';
import '../../core/utils/slug_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../providers/catalog_invalidator_provider.dart';
import '../providers/category_plp_hero_provider.dart';
import '../providers/category_providers.dart';
import '../providers/content_locale_provider.dart';
import '../providers/cms_page_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/product_providers.dart';
import '../providers/storefront_theme_providers.dart';
import '../navigation/route_visibility.dart';
import '../widgets/animations/add_to_cart_comet/add_to_cart_comet.dart';
import '../widgets/category_plp_hero.dart';
import '../widgets/cms/cms_admin_auth.dart';
import '../widgets/error_display.dart';
import '../widgets/hero_image_back_button.dart';
import '../widgets/navigation/sport_home_icon_loading_publisher.dart';
import '../widgets/plp_reorderable_product_tile.dart';
import '../widgets/product_card.dart';
import '../widgets/storefront_layout.dart';
import '../l10n/l10n_extension.dart';

import 'package:google_fonts/google_fonts.dart';

const kPlpHeroBackButtonKey = ValueKey<String>('plp-hero-back-button');
const kPlpLoadingHeaderSkeletonKey = ValueKey<String>(
  'plp-loading-header-skeleton',
);
const kPlpLoadingGridSkeletonKey = ValueKey<String>(
  'plp-loading-grid-skeleton',
);
@visibleForTesting
const kPlpAddToCartCometWarmUpHostKey = ValueKey<String>(
  'plp-add-to-cart-comet-warm-up-host',
);

const Duration _kAddToCartCometWarmUpDwell = Duration(milliseconds: 600);

@visibleForTesting
bool debugForceAddToCartCometWarmUpWeb = false;

@visibleForTesting
VoidCallback? debugOnAddToCartCometWarmUpScheduled;

typedef _PlpScrollControllerBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

class _PlpScrollControllerHost extends StatefulWidget {
  final _PlpScrollControllerBuilder builder;

  const _PlpScrollControllerHost({required this.builder});

  @override
  State<_PlpScrollControllerHost> createState() =>
      _PlpScrollControllerHostState();
}

class _PlpScrollControllerHostState extends State<_PlpScrollControllerHost> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _scrollController);
  }
}

class _AddToCartCometWarmUpHost extends StatefulWidget {
  /// All runtime gates resolved by the PLP build (mobile sport presentation,
  /// data ready, motion allowed). The host itself is mounted under a
  /// compile-time-stable condition only, so flipping [ready] never reshapes
  /// the element tree (a conditional wrapper here would remount the whole
  /// PLP subtree exactly when the data lands).
  final bool ready;
  final Widget child;

  const _AddToCartCometWarmUpHost({
    super.key,
    required this.ready,
    required this.child,
  });

  @override
  State<_AddToCartCometWarmUpHost> createState() =>
      _AddToCartCometWarmUpHostState();
}

class _AddToCartCometWarmUpHostState extends State<_AddToCartCometWarmUpHost> {
  Timer? _timer;
  bool _dwellStarted = false;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _maybeStartDwell();
  }

  @override
  void didUpdateWidget(covariant _AddToCartCometWarmUpHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartDwell();
  }

  /// The dwell starts once, on the first build where the runtime gates are
  /// satisfied (typically when the PLP data lands with product cards).
  void _maybeStartDwell() {
    if (_dwellStarted || !widget.ready) return;
    _dwellStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timer = Timer(_kAddToCartCometWarmUpDwell, _armIfStillVisible);
    });
  }

  void _armIfStillVisible() {
    _timer = null;
    if (!mounted || !widget.ready || !isCurrentRoute(context)) return;
    debugOnAddToCartCometWarmUpScheduled?.call();
    setState(() => _armed = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The warm-up layer sits UNDER an explicit opaque page fill: its frames
    // rasterize on the real surface but are never visible, including on empty
    // PLPs whose scroll content would otherwise leave transparent regions.
    return Stack(
      children: [
        Positioned.fill(child: AddToCartCometWarmUpLayer(armed: _armed)),
        Positioned.fill(
          child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        widget.child,
      ],
    );
  }
}

class ProductListPage extends ConsumerWidget {
  final String categoryId;

  /// Shared key for the category-tile → PLP Hero transition (the slug for
  /// `/catalog/<slug>`, or `id:<categoryId>` for the by-id route). Known
  /// synchronously from the route so the destination hero can mount on the
  /// first build and catch the inbound flight. Null disables the hero.
  final String? heroSlugKey;

  const ProductListPage({
    super.key,
    required this.categoryId,
    this.heroSlugKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plpAsync = ref.watch(plpProvider(categoryId));
    final plpState = plpAsync.value;
    final isInitialLoading = plpAsync.isLoading && plpState == null;
    final isRefreshing = plpAsync.isLoading && plpState != null;
    final isEditMode = ref.watch(editModeProvider);
    final categoryName = plpState?.categoryName;
    final theme =
        ref.watch(effectiveStorefrontThemeAsyncProvider).value ??
        StorefrontTheme.fallback;
    final profile = StorefrontPlpProfile.forTheme(theme);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(screenWidth);
    final loadConfiguredHero = !profile.prefersDirectCatalogGrid || isEditMode;
    final hasVisibleHero = _hasVisibleCategoryHero(
      ref,
      loadConfiguredHero: loadConfiguredHero,
    );
    final showHeroBackButton =
        hasVisibleHero &&
        isMobile &&
        profile.presentation == PlpPresentation.sportPerformance;
    // Mounting is gated on platform-stable conditions only; the runtime gates
    // feed the host's `ready` flag so the tree shape never flips.
    final canHostAddToCartCometWarmUp =
        kIsWeb || debugForceAddToCartCometWarmUpWeb;
    final addToCartCometWarmUpReady =
        isMobile &&
        plpState != null &&
        plpState.items.isNotEmpty &&
        profile.presentation == PlpPresentation.sportPerformance &&
        !MediaQuery.disableAnimationsOf(context);

    final page = _PlpScrollControllerHost(
      builder: (context, scrollController) {
        final scrollView = _buildScrollView(
          context,
          ref,
          scrollController: scrollController,
          profile: profile,
          plpAsync: plpAsync,
          plpState: plpState,
          isInitialLoading: isInitialLoading,
          isRefreshing: isRefreshing,
          isEditMode: isEditMode,
          categoryName: categoryName,
          showSportHeaderBackButton: !showHeroBackButton,
          loadConfiguredHero: loadConfiguredHero,
          hasVisibleHero: hasVisibleHero,
        );

        final body = showHeroBackButton
            ? _PlpHeroBackOverlay(
                onBack: () {
                  unawaited(
                    _goBackFromPlp(
                      context,
                      ref: ref,
                      categoryId: categoryId,
                      category: plpState?.category,
                    ),
                  );
                },
                triggerBubblePop: plpState != null,
                child: scrollView,
              )
            : scrollView;

        if (profile.filterPresentation !=
            PlpFilterPresentation.floatingAction) {
          return body;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            body,
            Positioned(
              right: 18,
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
              child: _FloatingFilterButton(
                onPressed: () => _handleFiltersTap(context),
              ),
            ),
          ],
        );
      },
    );

    final content = SportHomeIconLoadingPublisher(
      isLoading:
          profile.presentation == PlpPresentation.sportPerformance &&
          isInitialLoading,
      child: page,
    );
    if (!canHostAddToCartCometWarmUp) return content;
    return _AddToCartCometWarmUpHost(
      key: kPlpAddToCartCometWarmUpHostKey,
      ready: addToCartCometWarmUpReady,
      child: content,
    );
  }

  double _sportGridLeadingScrollExtent(
    BuildContext context, {
    required bool hasVisibleHero,
    required bool showSportHeaderBackButton,
    required bool isRefreshing,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    final heroExtent = heroSlugKey != null && hasVisibleHero
        ? MediaQuery.sizeOf(context).width
        : 0.0;
    final headerContentHeight = showSportHeaderBackButton
        ? kMinInteractiveDimension
        : 30.0;
    final headerExtent = topInset + 10 + headerContentHeight + 14;
    final refreshExtent = isRefreshing ? 4.0 : 0.0;
    return heroExtent + headerExtent + refreshExtent;
  }

  ProductCardStickyImageActionSpec? _stickyImageActionSpec(
    BuildContext context, {
    required bool isSport,
    required ScrollController scrollController,
    required int index,
    required int crossAxisCount,
    required double crossAxisExtent,
    required double childAspectRatio,
    required double gridSpacing,
    required double gridLeadingScrollExtent,
  }) {
    if (!isSport) return null;

    final itemCrossAxisExtent =
        (crossAxisExtent - (gridSpacing * (crossAxisCount - 1))) /
        crossAxisCount;
    if (itemCrossAxisExtent <= 0) return null;

    final itemMainAxisExtent = itemCrossAxisExtent / childAspectRatio;
    final row = index ~/ crossAxisCount;
    return ProductCardStickyImageActionSpec(
      scrollController: scrollController,
      imageScrollOffset:
          gridLeadingScrollExtent + row * (itemMainAxisExtent + gridSpacing),
      imageExtent: itemCrossAxisExtent,
      viewportPinTop: MediaQuery.paddingOf(context).top + 10,
    );
  }

  double _gridCrossAxisExtent(double screenWidth, double sidePadding) {
    return (screenWidth - (sidePadding * 2))
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  Widget _buildScrollView(
    BuildContext context,
    WidgetRef ref, {
    required ScrollController scrollController,
    required StorefrontPlpProfile profile,
    required AsyncValue<CatalogPageData> plpAsync,
    required CatalogPageData? plpState,
    required bool isInitialLoading,
    required bool isRefreshing,
    required bool isEditMode,
    required String? categoryName,
    required bool showSportHeaderBackButton,
    required bool loadConfiguredHero,
    required bool hasVisibleHero,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSport = profile.presentation == PlpPresentation.sportPerformance;
    final isMobile = StorefrontLayout.isMobile(screenWidth);
    // The sport reference is mobile-first. On wider viewports keep the
    // shared layout helpers so a Nike-themed PLP on tablet/desktop does
    // not turn into a brutal edge-to-edge wall; the card still uses the
    // sport presentation, but the page chrome stays restrained.
    final sportEdgeToEdge = isSport && isMobile;
    final sidePadding = sportEdgeToEdge
        ? 0.0
        : StorefrontLayout.outerPaddingFor(
            screenWidth,
            maxWidth: StorefrontLayout.productListMaxWidth,
          );
    final gridSpacing = sportEdgeToEdge
        ? kSportGridSpacing
        : StorefrontLayout.gridSpacingFor(screenWidth);
    final crossAxisCount = StorefrontLayout.productGridColumnsFor(screenWidth);
    final childAspectRatio = isSport
        ? kSportChildAspectRatio
        : StorefrontLayout.productGridAspectRatioFor(screenWidth);
    // MainShell inflates MediaQuery bottom padding to reserve room for the
    // sport floating bottom nav (luxe chrome leaves it at the system inset),
    // so honouring it here keeps the last grid row clear of the overlay on
    // every apparence without the PLP needing to know which nav is present.
    final bottomInset = MediaQuery.paddingOf(context).bottom + 32.0;
    final gridCrossAxisExtent = _gridCrossAxisExtent(screenWidth, sidePadding);
    final sportGridLeadingScrollExtent = isSport
        ? _sportGridLeadingScrollExtent(
            context,
            hasVisibleHero: hasVisibleHero,
            showSportHeaderBackButton: showSportHeaderBackButton,
            isRefreshing: isRefreshing,
          )
        : 0.0;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (heroSlugKey != null)
          SliverToBoxAdapter(
            child: CategoryPlpHero(
              slugKey: heroSlugKey!,
              categoryId: categoryId,
              loadConfiguredHero: loadConfiguredHero,
            ),
          ),
        SliverToBoxAdapter(
          child: _PlpHeader(
            profile: profile,
            categoryName: categoryName,
            fallbackCategoryName: context.l10n.plpCatalogueFallbackTitle,
            isLoading: isInitialLoading,
            categoryId: categoryId,
            category: plpState?.category,
            totalItems: plpState?.totalItems,
            showSportHeaderBackButton: showSportHeaderBackButton,
          ),
        ),
        if (isRefreshing)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (plpState != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              sidePadding,
              isSport ? 0 : 8,
              sidePadding,
              bottomInset,
            ),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: gridSpacing,
                mainAxisSpacing: gridSpacing,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (isEditMode && index == plpState.items.length) {
                  return _AddProductTile(
                    onTap: () => _handleCreateProduct(
                      context,
                      ref,
                      nextPosition: _nextCategoryProductPosition(
                        plpState.items,
                      ),
                    ),
                    onImageDropped: (bytes, filename) => _handleCreateProduct(
                      context,
                      ref,
                      nextPosition: _nextCategoryProductPosition(
                        plpState.items,
                      ),
                      droppedImageBytes: bytes,
                      droppedImageFilename: filename,
                    ),
                  );
                }

                final item = plpState.items[index];
                final productCard = ProductCard(
                  product: item.product,
                  prices: item.prices,
                  category: item.category,
                  routeName: CatalogRoutes.productLocation(
                    category: item.category,
                    product: item.product,
                    productSlug: item.productRouteSlug,
                  ),
                  enableHeroTransition: true,
                  presentation: profile.productCardPresentation,
                  stickyImageActionSpec: _stickyImageActionSpec(
                    context,
                    isSport: isSport,
                    scrollController: scrollController,
                    index: index,
                    crossAxisCount: crossAxisCount,
                    crossAxisExtent: gridCrossAxisExtent,
                    childAspectRatio: childAspectRatio,
                    gridSpacing: gridSpacing,
                    gridLeadingScrollExtent: sportGridLeadingScrollExtent,
                  ),
                );

                if (!isEditMode) {
                  return productCard;
                }

                return PlpReorderableProductTile(
                  item: item,
                  onAccept: (draggedItem) => _handleReorderProducts(
                    context,
                    ref,
                    items: plpState.items,
                    draggedItem: draggedItem,
                    targetItem: item,
                  ),
                  child: productCard,
                );
              }, childCount: plpState.items.length + (isEditMode ? 1 : 0)),
            ),
          )
        else if (plpAsync.hasError)
          SliverFillRemaining(
            child: ErrorDisplay(
              error: plpAsync.error!,
              onRetry: () => ref.invalidate(plpProvider(categoryId)),
            ),
          )
        else
          SliverPadding(
            key: kPlpLoadingGridSkeletonKey,
            padding: EdgeInsets.fromLTRB(
              sidePadding,
              isSport ? 0 : 8,
              sidePadding,
              bottomInset,
            ),
            sliver: _PlpLoadingGrid(
              isSport: isSport,
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              spacing: gridSpacing,
            ),
          ),
      ],
    );
  }

  void _handleFiltersTap(BuildContext context) {
    // TODO(plp-filters): wire to the real filter/sort surface when it ships.
    // The profile declares the affordance; the destination is left empty so
    // the button is visually present and behaviour follows once filters
    // exist in the model.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.plpFiltersComingSoon),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _hasVisibleCategoryHero(
    WidgetRef ref, {
    required bool loadConfiguredHero,
  }) {
    final slugKey = heroSlugKey;
    if (slugKey == null) {
      return false;
    }

    final hint = ref.watch(categoryPlpHeroShuttleProvider(slugKey));
    if (hint?.imageUrl.trim().isNotEmpty == true) {
      return true;
    }
    if (!loadConfiguredHero) {
      return false;
    }

    final locale = ref.watch(contentLocaleProvider);
    return ref.watch(
      cmsPlpProvider(
        CmsPlpRequest(categoryId: categoryId, locale: locale),
      ).select(_hasConfiguredHeroImage),
    );
  }

  Future<void> _handleCreateProduct(
    BuildContext context,
    WidgetRef ref, {
    required int nextPosition,
    Uint8List? droppedImageBytes,
    String? droppedImageFilename,
  }) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final draft = await _CreateProductDialog.show(
      context,
      initialImageBytes: droppedImageBytes,
      initialImageFilename: droppedImageFilename,
    );
    if (draft == null || draft.name.isEmpty) {
      return;
    }

    if (!context.mounted) return;

    final slug = slugify(draft.name, fallback: 'produit');
    final code = slug.toUpperCase();

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repository = ref.read(adminBackofficeRepositoryProvider);

    try {
      String? mediaId;
      if (draft.imageBytes != null && draft.imageFilename != null) {
        final optimized = ref
            .read(replaceMediaAssetProvider)
            .optimize(
              fileBytes: draft.imageBytes!,
              filename: draft.imageFilename!,
            );
        final mediaRecord = await repository.uploadMediaFromBytes(
          baseUrl: ref.read(apiBaseUrlProvider),
          authToken: token,
          fileBytes: optimized.fileBytes,
          filename: optimized.filename,
          mimeType: optimized.mimeType,
        );
        mediaId = mediaRecord['id'] as String?;
      }

      final product = await repository.createRecord(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'products',
        data: {
          'code': code,
          'name': draft.name,
          'slug': slug,
          'isActive': true,
          'picture': ?mediaId,
        },
      );

      final productId = product['id'] as String?;
      if (productId == null || productId.isEmpty) {
        throw StateError('Product created but id missing from response.');
      }

      await repository.createRecord(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categoryProducts',
        data: {
          'category': categoryId,
          'product': productId,
          'position': nextPosition,
          'isActive': true,
        },
      );

      ref
          .read(catalogInvalidatorProvider)
          .applyFromWidget(
            ref,
            invalidationsForCreatedProductInCategory(
              categoryId: categoryId,
              productId: productId,
            ),
          );

      Future<void>.microtask(() {
        router.go(
          CatalogRoutes.localizedLocation(
            CatalogRoutes.productById(productId),
            locale: ref.read(contentLocaleProvider),
          ),
        );
      });
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleReorderProducts(
    BuildContext context,
    WidgetRef ref, {
    required List<CatalogListingItem> items,
    required CatalogListingItem draggedItem,
    required CatalogListingItem targetItem,
  }) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(reorderCategoryProductsProvider)
          .call(
            authToken: token,
            items: [
              for (final item in items)
                CategoryProductOrderItem(
                  relationId: item.id,
                  position: item.position,
                ),
            ],
            draggedRelationId: draggedItem.id,
            targetRelationId: targetItem.id,
          );

      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, [
        CategoryPlpInvalidation(categoryId),
      ]);
      messenger.showSnackBar(
        const SnackBar(content: Text('Ordre des produits mis à jour.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d\'ordre: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  int _nextCategoryProductPosition(List<CatalogListingItem> items) {
    var maxPosition = 0;
    for (final item in items) {
      final position = item.position ?? 0;
      if (position > maxPosition) {
        maxPosition = position;
      }
    }
    return maxPosition + ReorderCategoryProducts.positionStep;
  }
}

/// Sport grid metrics, shared with the search results grid so a Nike-themed
/// search reads as a dense sport PLP rather than the editorial layout.
const double kSportGridSpacing = 2.0;
// Sport card: square image + Nike-like details block (newness, name, summary,
// price). Width/height ≈ 0.50 keeps two dense columns without clipping the
// product copy under normal mobile widths.
const double kSportChildAspectRatio = 0.5;

class _AddProductTile extends StatefulWidget {
  final VoidCallback onTap;
  final void Function(Uint8List bytes, String filename) onImageDropped;

  const _AddProductTile({required this.onTap, required this.onImageDropped});

  @override
  State<_AddProductTile> createState() => _AddProductTileState();
}

class _AddProductTileState extends State<_AddProductTile> {
  bool _hovering = false;

  Future<void> _handleDrop(DropDoneDetails detail) async {
    if (detail.files.isEmpty) return;
    final file = detail.files.first;
    final bytes = await file.readAsBytes();
    widget.onImageDropped(bytes, file.name);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (detail) {
        setState(() => _hovering = false);
        _handleDrop(detail);
      },
      child: Material(
        color: _hovering ? const Color(0xFFF7F7F4) : const Color(0xFFF9F9F7),
        child: InkWell(
          onTap: widget.onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F1EE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _hovering ? Icons.file_download_outlined : Icons.add,
                    color: const Color(0xFF2F2F2C),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _hovering ? 'Déposer l\'image' : 'Nouveau produit',
                  style: const TextStyle(
                    color: Color(0xFF2F2F2C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewProductDraft {
  final String name;
  final Uint8List? imageBytes;
  final String? imageFilename;

  const _NewProductDraft({
    required this.name,
    this.imageBytes,
    this.imageFilename,
  });
}

class _CreateProductDialog extends StatefulWidget {
  final Uint8List? initialImageBytes;
  final String? initialImageFilename;

  const _CreateProductDialog({
    this.initialImageBytes,
    this.initialImageFilename,
  });

  static Future<_NewProductDraft?> show(
    BuildContext context, {
    Uint8List? initialImageBytes,
    String? initialImageFilename,
  }) {
    return showDialog<_NewProductDraft>(
      context: context,
      builder: (_) => _CreateProductDialog(
        initialImageBytes: initialImageBytes,
        initialImageFilename: initialImageFilename,
      ),
    );
  }

  @override
  State<_CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<_CreateProductDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _NewProductDraft(
        name: name,
        imageBytes: widget.initialImageBytes,
        imageFilename: widget.initialImageFilename,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = widget.initialImageBytes;
    return AlertDialog(
      title: const Text('Nouveau produit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                imageBytes,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 140,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: kNavyBlue),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.initialImageFilename ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom du produit'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
          child: const Text('Créer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _PlpHeader extends StatelessWidget {
  final StorefrontPlpProfile profile;
  final String? categoryName;
  final String fallbackCategoryName;
  final bool isLoading;
  final String categoryId;
  final CatalogCategory? category;
  final int? totalItems;
  final bool showSportHeaderBackButton;

  const _PlpHeader({
    required this.profile,
    required this.categoryName,
    required this.fallbackCategoryName,
    required this.isLoading,
    required this.categoryId,
    required this.category,
    required this.totalItems,
    required this.showSportHeaderBackButton,
  });

  @override
  Widget build(BuildContext context) {
    switch (profile.presentation) {
      case PlpPresentation.editorial:
        // The editorial header has no in-page back affordance; it relies on
        // browser/Navigator back, so it does not need parent resolution.
        return _EditorialHeader(
          categoryName: categoryName,
          fallbackCategoryName: fallbackCategoryName,
          isLoading: isLoading,
          totalItems: totalItems,
        );
      case PlpPresentation.sportPerformance:
        return _SportHeader(
          categoryName: categoryName,
          fallbackCategoryName: fallbackCategoryName,
          isLoading: isLoading,
          categoryId: categoryId,
          category: category,
          showBackButton: showSportHeaderBackButton,
        );
    }
  }
}

class _EditorialHeader extends StatelessWidget {
  final String? categoryName;
  final String fallbackCategoryName;
  final bool isLoading;
  final int? totalItems;

  const _EditorialHeader({
    required this.categoryName,
    required this.fallbackCategoryName,
    required this.isLoading,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(screenWidth);

    return StorefrontPageSection(
      maxWidth: StorefrontLayout.productListMaxWidth,
      padding: EdgeInsets.fromLTRB(
        0,
        isMobile ? 48 : 64,
        0,
        isMobile ? 32 : 48,
      ),
      child: Column(
        children: [
          if (isLoading && categoryName == null)
            Center(
              child: _PlpSkeletonBlock(
                key: kPlpLoadingHeaderSkeletonKey,
                width: isMobile ? 188 : 260,
                height: isMobile ? 36 : 48,
                radius: 8,
              ),
            )
          else
            Text(
              categoryName ?? fallbackCategoryName,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 32 : 44,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          const SizedBox(height: 8),
          _ProductsCount(totalItems: totalItems),
        ],
      ),
    );
  }
}

class _SportHeader extends ConsumerWidget {
  final String? categoryName;
  final String fallbackCategoryName;
  final bool isLoading;
  final String categoryId;
  final CatalogCategory? category;
  final bool showBackButton;

  const _SportHeader({
    required this.categoryName,
    required this.fallbackCategoryName,
    required this.isLoading,
    required this.categoryId,
    required this.category,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        showBackButton ? 4 : 24,
        MediaQuery.paddingOf(context).top + 10,
        16,
        14,
      ),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              tooltip: context.l10n.plpBackToPreviousLevel,
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF111111),
                size: 30,
              ),
              onPressed: () {
                unawaited(
                  _goBackFromPlp(
                    context,
                    ref: ref,
                    categoryId: categoryId,
                    category: category,
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: isLoading && categoryName == null
                ? const _PlpSkeletonBlock(
                    key: kPlpLoadingHeaderSkeletonKey,
                    width: 180,
                    height: 30,
                    radius: 7,
                  )
                : Text(
                    categoryName ?? fallbackCategoryName,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                      letterSpacing: 0,
                      height: 1.08,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlpLoadingGrid extends StatelessWidget {
  final bool isSport;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const _PlpLoadingGrid({
    required this.isSport,
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = (crossAxisCount * (isSport ? 3 : 2)).clamp(4, 8);
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      delegate: SliverChildBuilderDelegate(
        (_, index) => _PlpLoadingCard(isSport: isSport),
        childCount: itemCount,
      ),
    );
  }
}

class _PlpLoadingCard extends StatelessWidget {
  final bool isSport;

  const _PlpLoadingCard({required this.isSport});

  @override
  Widget build(BuildContext context) {
    if (isSport) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _PlpSkeletonBlock(width: double.infinity, height: 0),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlpSkeletonBlock(width: 132, height: 20, radius: 5),
                SizedBox(height: 8),
                _PlpSkeletonBlock(width: 104, height: 16, radius: 5),
                SizedBox(height: 18),
                _PlpSkeletonBlock(width: 72, height: 22, radius: 5),
              ],
            ),
          ),
        ],
      );
    }

    return const Column(
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: _PlpSkeletonBlock(width: double.infinity, height: 0),
        ),
        SizedBox(height: 18),
        _PlpSkeletonBlock(width: 148, height: 18, radius: 5),
        SizedBox(height: 10),
        _PlpSkeletonBlock(width: 78, height: 16, radius: 5),
      ],
    );
  }
}

class _PlpSkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _PlpSkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height == 0 ? double.infinity : height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _PlpHeroBackOverlay extends StatefulWidget {
  final VoidCallback onBack;
  final bool triggerBubblePop;
  final Widget child;

  const _PlpHeroBackOverlay({
    required this.onBack,
    required this.triggerBubblePop,
    required this.child,
  });

  @override
  State<_PlpHeroBackOverlay> createState() => _PlpHeroBackOverlayState();
}

class _PlpHeroBackOverlayState extends State<_PlpHeroBackOverlay> {
  static const double _topGap = 16;
  static const double _leftGap = 18;

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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + _topGap;
    final heroHeight = MediaQuery.sizeOf(context).width;
    final visibleUntilScroll = (heroHeight - top - kHeroImageBackButtonSize)
        .clamp(0.0, double.infinity)
        .toDouble();
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
          left: _leftGap,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              opacity: isVisible ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: HeroImageBackButton(
                buttonKey: kPlpHeroBackButtonKey,
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

bool _hasConfiguredHeroImage(AsyncValue<CmsPageBundle?> async) {
  final bundle = async.value;
  if (bundle == null) {
    return false;
  }
  for (final section in bundle.sections) {
    if (section is CmsHeroSection && _heroConfigHasImage(section.data)) {
      return true;
    }
  }
  return false;
}

bool _heroConfigHasImage(HeroCampaignConfig config) {
  return (config.mediaDesktop?.isUsable ?? false) ||
      (config.mediaMobile?.isUsable ?? false);
}

Future<void> _goBackFromPlp(
  BuildContext context, {
  required WidgetRef ref,
  required String categoryId,
  required CatalogCategory? category,
}) async {
  final router = _maybeRouter(context);
  if (router == null) {
    // Plain Navigator host (no GoRouter, e.g. some tests): best-effort pop.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return;
  }

  // Prefer real history. go_router's canPop spans the root + shell navigators,
  // so it sees a drawer push of this PLP even though the PLP renders inside
  // MainShell while the page it was opened from lives on the root navigator.
  // Navigator.of(context) would only see the shell's inner stack and miss that
  // entry, sending the user up the catalog hierarchy.
  if (router.canPop()) {
    router.pop();
    return;
  }

  final availableCategories = await _readAvailableCategoriesForBack(ref);
  if (!context.mounted) return;

  final currentUri = router.routeInformationProvider.value.uri;
  final currentLocale = resolveLocaleRoute(currentUri).effectiveLocale;
  final destination = PlpParentRouting.resolveParentLocation(
    currentUri: currentUri,
    catalogBaseLocation: CatalogRoutes.localizedLocation(
      CatalogRoutes.catalogBase,
      locale: currentLocale.languageCode,
    ),
    currentCategory: category,
    currentCategoryId: categoryId,
    availableCategories: availableCategories,
  );
  router.go(
    CatalogRoutes.localizedLocation(
      destination,
      locale: currentLocale.languageCode,
    ),
  );
}

Future<List<CatalogCategory>> _readAvailableCategoriesForBack(
  WidgetRef ref,
) async {
  final current = ref.read(activeCategoriesProvider);
  if (current.hasValue) {
    return current.value ?? const <CatalogCategory>[];
  }
  try {
    return await ref
        .read(activeCategoriesProvider.future)
        .timeout(const Duration(milliseconds: 150));
  } catch (_) {
    return const <CatalogCategory>[];
  }
}

GoRouter? _maybeRouter(BuildContext context) {
  try {
    return GoRouter.of(context);
  } catch (_) {
    return null;
  }
}

class _ProductsCount extends StatelessWidget {
  final int? totalItems;

  const _ProductsCount({required this.totalItems});

  @override
  Widget build(BuildContext context) {
    if (totalItems == null) {
      return const SizedBox.shrink();
    }
    final count = totalItems!;
    return Text(
      context.l10n.plpProductsCount(count),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF6F6F6F),
      ),
    );
  }
}

class _FloatingFilterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _FloatingFilterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.plpFilterAndSort,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.tune, color: Color(0xFF111111), size: 22),
          ),
        ),
      ),
    );
  }
}
