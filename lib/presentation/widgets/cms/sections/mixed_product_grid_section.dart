import 'dart:math' as math;
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/catalog_routes.dart';
import '../../../../application/admin/reorder_category_products.dart';
import '../../../../application/catalog/catalog_invalidations.dart';
import '../../../../application/cms/cms_models.dart';
import '../../../../application/cms/mixed_product_grid_composer.dart';
import '../../../../core/utils/slug_utils.dart';
import '../../../../domain/catalog/catalog_entities.dart';
import '../../../providers/catalog_invalidator_provider.dart';
import '../../../providers/cms_mixed_grid_products_provider.dart';
import '../../../providers/content_locale_provider.dart';
import '../../../providers/edit_mode_provider.dart';
import '../cms_admin_auth.dart';
import '../../kiki_image.dart';
import '../../landing_asset_loading_backdrop.dart';
import '../../plp_reorderable_product_tile.dart';
import '../../product_card.dart';
import '../../storefront_layout.dart';
import '../cms_href.dart';
import '../cms_text_reveal.dart';

import 'package:google_fonts/google_fonts.dart';

const _kMixedGridProductAspectRatio = 0.48;
const _kMixedGridSkeletonColor = Color(0xFFF0EEE8);

class MixedProductGridSection extends ConsumerStatefulWidget {
  final MixedProductGridConfig config;
  final String? routeCategoryId;
  final CatalogCategory? routeCategory;
  final bool enableTextReveal;
  final String? textRevealId;

  /// Enables the PLP→PDP product image Hero transition for the cards in this
  /// grid. Only the true catalogue PLP opts in — kept false for the homepage,
  /// search and arbitrary CMS surfaces to avoid duplicate Hero tags.
  final bool enableProductHeroTransition;

  const MixedProductGridSection({
    super.key,
    required this.config,
    required this.routeCategoryId,
    this.routeCategory,
    this.enableProductHeroTransition = false,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  ConsumerState<MixedProductGridSection> createState() =>
      _MixedProductGridSectionState();
}

class _MixedProductGridSectionState
    extends ConsumerState<MixedProductGridSection> {
  late String _activeSort;

  @override
  void initState() {
    super.initState();
    _activeSort = _normalizedSort(widget.config.toolbar.defaultSort);
  }

  @override
  void didUpdateWidget(covariant MixedProductGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.toolbar.defaultSort !=
        widget.config.toolbar.defaultSort) {
      _activeSort = _normalizedSort(widget.config.toolbar.defaultSort);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeCategoryId = widget.routeCategoryId;
    if (routeCategoryId == null || routeCategoryId.isEmpty) {
      return const SizedBox.shrink();
    }
    final isEditMode = ref.watch(editModeProvider);

    final asyncData = ref.watch(
      cmsMixedGridProductsProvider((
        categoryId: routeCategoryId,
        limit: widget.config.source.limit,
      )),
    );

    return LandingGradientLoadingBackground(
      idleBackgroundColor: Colors.white,
      child: asyncData.hasError
          ? const _MixedGridErrorBody()
          : asyncData.when(
              loading: () => _MixedGridLoadingBody(
                config: widget.config,
                categoryName: widget.routeCategory?.name,
              ),
              error: (_, _) => const _MixedGridErrorBody(),
              data: (data) {
                final items = MixedProductGridComposer.compose(
                  products: data.items,
                  config: widget.config,
                  activeSort: _activeSort,
                );
                final visibleProductItems = items
                    .whereType<MixedGridProductItem>()
                    .map((item) => item.listingItem)
                    .toList(growable: false);
                final nextPosition = _nextCategoryProductPosition(data.items);
                return _MixedGridBody(
                  config: widget.config,
                  enableProductHeroTransition:
                      widget.enableProductHeroTransition,
                  enableTextReveal: widget.enableTextReveal,
                  textRevealId: widget.textRevealId,
                  categoryName: data.categoryName,
                  productCount: data.totalItems,
                  items: items,
                  activeSort: _activeSort,
                  onSortChanged: (sort) => setState(() => _activeSort = sort),
                  showAddProductTile: isEditMode,
                  onAddProduct: () => _handleCreateProduct(
                    context,
                    routeCategoryId,
                    nextPosition: nextPosition,
                  ),
                  onProductImageDropped: (bytes, filename) =>
                      _handleCreateProduct(
                        context,
                        routeCategoryId,
                        nextPosition: nextPosition,
                        droppedImageBytes: bytes,
                        droppedImageFilename: filename,
                      ),
                  onReorderProduct: (draggedItem, targetItem) =>
                      _handleReorderProducts(
                        context,
                        routeCategoryId,
                        items: visibleProductItems,
                        draggedItem: draggedItem,
                        targetItem: targetItem,
                      ),
                );
              },
            ),
    );
  }

  Future<void> _handleCreateProduct(
    BuildContext context,
    String categoryId, {
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
    if (draft == null || draft.name.isEmpty) return;

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
      ref.invalidate(
        cmsMixedGridProductsProvider((
          categoryId: categoryId,
          limit: widget.config.source.limit,
        )),
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
    String categoryId, {
    required List<CatalogListingItem> items,
    required CatalogListingItem draggedItem,
    required CatalogListingItem targetItem,
  }) async {
    if (draggedItem.id == targetItem.id) return;

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

      if (!mounted) return;
      setState(() => _activeSort = 'manual');
      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, [
        CategoryPlpInvalidation(categoryId),
      ]);
      ref.invalidate(
        cmsMixedGridProductsProvider((
          categoryId: categoryId,
          limit: widget.config.source.limit,
        )),
      );
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

class _MixedGridBody extends StatelessWidget {
  final MixedProductGridConfig config;
  final bool enableProductHeroTransition;
  final bool enableTextReveal;
  final String? textRevealId;
  final String? categoryName;
  final int productCount;
  final List<MixedGridItem> items;
  final String activeSort;
  final ValueChanged<String> onSortChanged;
  final bool showAddProductTile;
  final VoidCallback onAddProduct;
  final void Function(Uint8List bytes, String filename) onProductImageDropped;
  final void Function(
    CatalogListingItem draggedItem,
    CatalogListingItem targetItem,
  )
  onReorderProduct;

  const _MixedGridBody({
    required this.config,
    required this.enableProductHeroTransition,
    required this.enableTextReveal,
    required this.textRevealId,
    this.categoryName,
    required this.productCount,
    required this.items,
    required this.activeSort,
    required this.onSortChanged,
    required this.showAddProductTile,
    required this.onAddProduct,
    required this.onProductImageDropped,
    required this.onReorderProduct,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sidePadding = _mixedGridSidePadding(width);

    return Padding(
      padding: EdgeInsets.fromLTRB(sidePadding, 48, sidePadding, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GridToolbar(
            config: config.toolbar,
            enableTextReveal: enableTextReveal,
            textRevealId: textRevealId,
            categoryName: categoryName,
            productCount: productCount,
            activeSort: activeSort,
            onSortChanged: onSortChanged,
          ),
          const SizedBox(height: 48),
          _ResponsiveMixedGrid(
            config: config,
            enableProductHeroTransition: enableProductHeroTransition,
            items: items,
            showAddProductTile: showAddProductTile,
            onAddProduct: onAddProduct,
            onProductImageDropped: onProductImageDropped,
            onReorderProduct: onReorderProduct,
          ),
        ],
      ),
    );
  }
}

class _MixedGridLoadingBody extends StatelessWidget {
  final MixedProductGridConfig config;
  final String? categoryName;

  const _MixedGridLoadingBody({required this.config, this.categoryName});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sidePadding = _mixedGridSidePadding(width);
    final minHeight = MediaQuery.sizeOf(context).height * 0.88;

    return LandingGradientLoadingSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(sidePadding, 48, sidePadding, 80),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GridToolbarSkeleton(categoryName: categoryName),
              const SizedBox(height: 48),
              _ResponsiveMixedGridSkeleton(config: config),
            ],
          ),
        ),
      ),
    );
  }
}

class _MixedGridErrorBody extends StatelessWidget {
  const _MixedGridErrorBody();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sidePadding = _mixedGridSidePadding(width);

    return Padding(
      padding: EdgeInsets.fromLTRB(sidePadding, 48, sidePadding, 80),
      child: Container(
        constraints: const BoxConstraints(minHeight: 220),
        alignment: Alignment.center,
        color: Colors.white,
        child: const Text(
          'Impossible de charger les produits pour le moment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6F6F6F), fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}

class _GridToolbarSkeleton extends StatelessWidget {
  final String? categoryName;

  const _GridToolbarSkeleton({this.categoryName});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final resolvedCategoryName = categoryName?.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (resolvedCategoryName != null && resolvedCategoryName.isNotEmpty)
          Text(
            resolvedCategoryName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: isMobile ? 32 : 44,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1B1B1B),
            ),
          )
        else
          const _SkeletonBlock(width: 190, height: 42),
        const SizedBox(height: 10),
        const _SkeletonBlock(width: 82, height: 14),
      ],
    );
  }
}

class _ResponsiveMixedGridSkeleton extends StatelessWidget {
  final MixedProductGridConfig config;

  const _ResponsiveMixedGridSkeleton({required this.config});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = _columnsFor(width, config);
    final spacing = _mixedGridSpacing(width);
    final rowGap = _mixedGridRowGap(width);
    final rowCount = StorefrontLayout.isMobile(width) ? 3 : 2;
    final rows = List.generate(
      rowCount,
      (_) => List.generate(columns, (_) => const _PackedSkeletonCell(span: 1)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final unitWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Column(
          key: const ValueKey('mixed-product-grid-skeleton'),
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              _SkeletonGridRow(
                row: rows[rowIndex],
                unitWidth: unitWidth,
                spacing: spacing,
              ),
              if (rowIndex < rows.length - 1 && rowGap > 0)
                SizedBox(height: rowGap),
            ],
          ],
        );
      },
    );
  }
}

class _PackedSkeletonCell {
  final int span;

  const _PackedSkeletonCell({required this.span});
}

class _SkeletonGridRow extends StatelessWidget {
  final List<_PackedSkeletonCell> row;
  final double unitWidth;
  final double spacing;

  const _SkeletonGridRow({
    required this.row,
    required this.unitWidth,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight = row
        .map((cell) => _skeletonHeightFor(cell, unitWidth, spacing))
        .fold<double>(0, math.max);

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < row.length; i++) ...[
            SizedBox(
              width: unitWidth * row[i].span + spacing * (row[i].span - 1),
              child: const _ProductCardSkeleton(),
            ),
            if (i < row.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ColoredBox(color: _kMixedGridSkeletonColor)),
        SizedBox(height: 12),
        _SkeletonBlock(height: 13),
        SizedBox(height: 8),
        _SkeletonBlock(width: 96, height: 12),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;

  const _SkeletonBlock({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: width ?? fallbackWidth,
            height: height,
            decoration: BoxDecoration(
              color: _kMixedGridSkeletonColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}

class _GridToolbar extends StatelessWidget {
  final GridToolbarConfig config;
  final bool enableTextReveal;
  final String? textRevealId;
  final String? categoryName;
  final int productCount;
  final String activeSort;
  final ValueChanged<String> onSortChanged;

  const _GridToolbar({
    required this.config,
    required this.enableTextReveal,
    required this.textRevealId,
    this.categoryName,
    required this.productCount,
    required this.activeSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);

    return CmsRevealGroup(
      key: textRevealId == null
          ? null
          : ValueKey('cms-mixed-product-grid-toolbar-reveal-$textRevealId'),
      trigger: CmsRevealTrigger.viewport,
      enabled: enableTextReveal,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (categoryName != null)
          CmsRevealText(
            child: Text(
              categoryName!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: isMobile ? 32 : 44,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          ),
        const SizedBox(height: 8),
        CmsRevealText(
          child: Text(
            '$productCount article${productCount > 1 ? 's' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6F6F6F),
            ),
          ),
        ),
        // If sorting/filtering are enabled, we might want to keep them but
        // maybe in a different layout? Dior screenshot shows "Filtrer & Trier"
        // in a floating/bottom button sometimes, or a very clean row.
        // For now, I'll stick to the core redesign requested.
      ],
    );
  }
}

class _ResponsiveMixedGrid extends StatelessWidget {
  final MixedProductGridConfig config;
  final bool enableProductHeroTransition;
  final List<MixedGridItem> items;
  final bool showAddProductTile;
  final VoidCallback onAddProduct;
  final void Function(Uint8List bytes, String filename) onProductImageDropped;
  final void Function(
    CatalogListingItem draggedItem,
    CatalogListingItem targetItem,
  )
  onReorderProduct;

  const _ResponsiveMixedGrid({
    required this.config,
    required this.enableProductHeroTransition,
    required this.items,
    required this.showAddProductTile,
    required this.onAddProduct,
    required this.onProductImageDropped,
    required this.onReorderProduct,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = _columnsFor(width, config);
    final spacing = _mixedGridSpacing(width);
    final rowGap = _mixedGridRowGap(width);
    final entries = [
      for (final item in items) _ContentGridEntry(item),
      if (showAddProductTile)
        _AddProductGridEntry(
          onTap: onAddProduct,
          onImageDropped: onProductImageDropped,
        ),
    ];
    final rows = _packRows(entries, columns, width);

    return LayoutBuilder(
      builder: (context, constraints) {
        final unitWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Column(
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              _GridRow(
                row: rows[rowIndex],
                enableProductHeroTransition: enableProductHeroTransition,
                columns: columns,
                unitWidth: unitWidth,
                spacing: spacing,
                productAspectRatio: _kMixedGridProductAspectRatio,
                enableProductReorder: showAddProductTile,
                onReorderProduct: onReorderProduct,
              ),
              if (rowIndex < rows.length - 1 && rowGap > 0)
                SizedBox(height: rowGap),
            ],
          ],
        );
      },
    );
  }
}

class _GridRow extends StatelessWidget {
  final List<_PackedCell> row;
  final bool enableProductHeroTransition;
  final int columns;
  final double unitWidth;
  final double spacing;
  final double productAspectRatio;
  final bool enableProductReorder;
  final void Function(
    CatalogListingItem draggedItem,
    CatalogListingItem targetItem,
  )
  onReorderProduct;

  const _GridRow({
    required this.row,
    required this.enableProductHeroTransition,
    required this.columns,
    required this.unitWidth,
    required this.spacing,
    required this.productAspectRatio,
    required this.enableProductReorder,
    required this.onReorderProduct,
  });

  @override
  Widget build(BuildContext context) {
    final rowHeight = row
        .map((cell) => _heightFor(cell, unitWidth, spacing, productAspectRatio))
        .fold<double>(0, math.max);

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < row.length; i++) ...[
            SizedBox(
              width: unitWidth * row[i].span + spacing * (row[i].span - 1),
              child: _GridCell(
                item: row[i].item,
                enableProductReorder: enableProductReorder,
                enableProductHeroTransition: enableProductHeroTransition,
                onReorderProduct: onReorderProduct,
              ),
            ),
            if (i < row.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  final _GridEntry item;
  final bool enableProductReorder;
  final bool enableProductHeroTransition;
  final void Function(
    CatalogListingItem draggedItem,
    CatalogListingItem targetItem,
  )
  onReorderProduct;

  const _GridCell({
    required this.item,
    required this.enableProductReorder,
    required this.enableProductHeroTransition,
    required this.onReorderProduct,
  });

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      _ContentGridEntry(item: MixedGridProductItem(:final listingItem)) =>
        _ProductGridCell(
          listingItem: listingItem,
          enableProductReorder: enableProductReorder,
          onReorderProduct: onReorderProduct,
          child: ProductCard(
            product: listingItem.product,
            prices: listingItem.prices,
            category: listingItem.category,
            routeName: CatalogRoutes.productLocation(
              category: listingItem.category,
              product: listingItem.product,
              productSlug: listingItem.productRouteSlug,
            ),
            enableHeroTransition: enableProductHeroTransition,
          ),
        ),
      _ContentGridEntry(item: MixedGridInsertItem(:final insert)) =>
        _InsertTile(insert: insert),
      _AddProductGridEntry(:final onTap, :final onImageDropped) =>
        _AddProductTile(onTap: onTap, onImageDropped: onImageDropped),
    };
  }
}

class _ProductGridCell extends StatelessWidget {
  final CatalogListingItem listingItem;
  final bool enableProductReorder;
  final void Function(
    CatalogListingItem draggedItem,
    CatalogListingItem targetItem,
  )
  onReorderProduct;
  final Widget child;

  const _ProductGridCell({
    required this.listingItem,
    required this.enableProductReorder,
    required this.onReorderProduct,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableProductReorder) {
      return child;
    }

    return PlpReorderableProductTile(
      item: listingItem,
      onAccept: (draggedItem) => onReorderProduct(draggedItem, listingItem),
      child: child,
    );
  }
}

class _InsertTile extends StatelessWidget {
  final GridInsertConfig insert;

  const _InsertTile({required this.insert});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final media = switch (insert) {
      CategoryTileInsert(:final imageDesktop, :final imageMobile) =>
        StorefrontLayout.isDesktop(width)
            ? (imageDesktop ?? imageMobile)
            : (imageMobile ?? imageDesktop),
      EditorialCampaignInsert(:final imageDesktop, :final imageMobile) =>
        StorefrontLayout.isDesktop(width)
            ? (imageDesktop ?? imageMobile)
            : (imageMobile ?? imageDesktop),
      UniverseInsert(:final imageDesktop, :final imageMobile) =>
        StorefrontLayout.isDesktop(width)
            ? (imageDesktop ?? imageMobile)
            : (imageMobile ?? imageDesktop),
      UnknownGridInsert() => null,
    };

    return InkWell(
      onTap: () => _launchInsert(context, insert),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media != null)
            KikiImage(
              imageUrl: media.thumbUrl(size: '900x900'),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(color: const Color(0xFFEDEAE3)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.46),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _InsertCopy(insert: insert),
          ),
        ],
      ),
    );
  }
}

class _InsertCopy extends StatelessWidget {
  final GridInsertConfig insert;

  const _InsertCopy({required this.insert});

  @override
  Widget build(BuildContext context) {
    final title = switch (insert) {
      CategoryTileInsert(:final title) => title,
      EditorialCampaignInsert(:final title) => title,
      UniverseInsert(:final title) => title,
      UnknownGridInsert() => '',
    };
    final body = switch (insert) {
      EditorialCampaignInsert(:final body) => body,
      UniverseInsert(:final body) => body,
      _ => null,
    };
    final cta = insert is EditorialCampaignInsert
        ? (insert as EditorialCampaignInsert).cta?.label
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
        if (cta != null) ...[
          const SizedBox(height: 8),
          Text(
            cta,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }
}

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
      child: InkWell(
        onTap: widget.onTap,
        child: ColoredBox(
          color: _hovering ? const Color(0xFFF7F7F4) : const Color(0xFFF9F9F7),
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
                  child: const Icon(
                    Icons.broken_image,
                    color: Color(0xFF2F2F2C),
                  ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F2F2C),
          ),
          child: const Text('Créer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

sealed class _GridEntry {
  const _GridEntry();
}

class _ContentGridEntry extends _GridEntry {
  final MixedGridItem item;

  const _ContentGridEntry(this.item);
}

class _AddProductGridEntry extends _GridEntry {
  final VoidCallback onTap;
  final void Function(Uint8List bytes, String filename) onImageDropped;

  const _AddProductGridEntry({
    required this.onTap,
    required this.onImageDropped,
  });
}

class _PackedCell {
  final _GridEntry item;
  final int span;

  const _PackedCell({required this.item, required this.span});
}

List<List<_PackedCell>> _packRows(
  List<_GridEntry> items,
  int columns,
  double width,
) {
  final rows = <List<_PackedCell>>[];
  var current = <_PackedCell>[];
  var used = 0;
  for (final item in items) {
    final span = _spanFor(item, columns, width);
    if (used > 0 && used + span > columns) {
      rows.add(current);
      current = <_PackedCell>[];
      used = 0;
    }
    current.add(_PackedCell(item: item, span: span));
    used += span;
    if (used >= columns) {
      rows.add(current);
      current = <_PackedCell>[];
      used = 0;
    }
  }
  if (current.isNotEmpty) rows.add(current);
  return rows;
}

int _spanFor(_GridEntry item, int columns, double width) {
  if (item case _ContentGridEntry(item: MixedGridInsertItem(:final insert))) {
    final size = insert.displaySize;
    final isMobile = StorefrontLayout.isMobile(width);
    final span = switch (size) {
      'wide' => 2,
      'full_mobile' => isMobile ? columns : 2,
      _ => 1,
    };
    return span.clamp(1, columns);
  }
  return 1;
}

int _columnsFor(double width, MixedProductGridConfig config) {
  if (StorefrontLayout.isDesktop(width)) return config.columnsDesktop;
  if (StorefrontLayout.isTabletOnly(width)) return config.columnsTablet;
  return config.columnsMobile;
}

double _mixedGridSidePadding(double width) {
  // On desktop, the grid runs edge-to-edge with no outer side padding.
  return StorefrontLayout.isDesktop(width)
      ? 0.0
      : StorefrontLayout.outerPaddingFor(
          width,
          maxWidth: StorefrontLayout.productListMaxWidth,
        );
}

double _mixedGridSpacing(double width) {
  // On desktop, products butt up against each other with no gap.
  return StorefrontLayout.isDesktop(width)
      ? 0.0
      : StorefrontLayout.gridSpacingFor(width);
}

double _mixedGridRowGap(double width) {
  if (StorefrontLayout.isDesktop(width)) return 0.0;
  return StorefrontLayout.isMobile(width) ? 32.0 : 48.0;
}

double _skeletonHeightFor(
  _PackedSkeletonCell cell,
  double unitWidth,
  double spacing,
) {
  final width = unitWidth * cell.span + spacing * (cell.span - 1);
  return width / _kMixedGridProductAspectRatio;
}

double _heightFor(
  _PackedCell cell,
  double unitWidth,
  double spacing,
  double productAspectRatio,
) {
  final width = unitWidth * cell.span + spacing * (cell.span - 1);
  final ratio = switch (cell.item) {
    _ContentGridEntry(item: MixedGridProductItem()) => productAspectRatio,
    _ContentGridEntry(item: MixedGridInsertItem(:final insert)) => _doubleRatio(
      insert.aspectRatio,
      cell.span > 1 ? 16 / 9 : 1,
    ),
    _AddProductGridEntry() => productAspectRatio,
  };
  return width / ratio;
}

double _doubleRatio(String raw, double fallback) {
  final value = raw.trim();
  if (value.contains('/')) {
    final parts = value.split('/');
    if (parts.length == 2) {
      final left = double.tryParse(parts[0].trim());
      final right = double.tryParse(parts[1].trim());
      if (left != null && right != null && right > 0) {
        return left / right;
      }
    }
  }
  final parsed = double.tryParse(value);
  if (parsed == null || parsed <= 0) return fallback;
  return parsed;
}

void _launchInsert(BuildContext context, GridInsertConfig insert) {
  final href = switch (insert) {
    CategoryTileInsert(:final href) => href,
    EditorialCampaignInsert(:final cta) => cta?.href,
    UniverseInsert(:final href) => href,
    UnknownGridInsert() => null,
  };
  if (href == null || href.trim().isEmpty) return;
  launchCmsHref(context, href);
}

String _normalizedSort(String value) {
  return switch (value) {
    'manual' || 'newest' || 'price_asc' || 'price_desc' => value,
    _ => 'manual',
  };
}
