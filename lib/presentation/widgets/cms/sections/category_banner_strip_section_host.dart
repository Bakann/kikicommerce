import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/cms/cms_models.dart';
import '../../../../application/navigation/drawer_navigation_models.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/edit_mode_provider.dart';
import '../../../providers/navigation_providers.dart';
import 'category_banner_strip_resolver.dart';
import 'category_banner_strip_section.dart';

/// Host widget for the CMS `category_banner_strip` section.
///
/// Watches the live drawer provider and (when the drawer is in `categories`
/// mode) the categories provider, resolves the visible root items into
/// banner items, and hands them to the pure visual widget. Hidden items
/// are never surfaced on the storefront — even in edit mode — because the
/// admin uses the section's editor form to manage hidden state.
class CategoryBannerStripSectionHost extends ConsumerWidget {
  final CategoryBannerStripConfig config;

  const CategoryBannerStripSectionHost({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (config.sourceMode == CategoryBannerStripSourceMode.configuredBanners) {
      return CategoryBannerStripSection(
        items: config.configuredBanners,
        sharedBackgroundMedia: config.sharedBackgroundMedia,
      );
    }

    final isEditMode = ref.watch(editModeProvider);
    final drawerAsync = ref.watch(mainDrawerNavigationProvider);
    final drawer = drawerAsync.value;
    if (drawer == null && drawerAsync.isLoading && !drawerAsync.hasError) {
      return CategoryBannerStripSkeleton(
        itemCount: config.skeletonItemCount,
        appearance: config.bannerAppearance.values.toList(growable: false),
      );
    }

    final liveSource = drawer?.menu?.liveSource ?? DrawerLiveSource.navigation;
    final isCategoryChildrenMode =
        config.sourceMode == CategoryBannerStripSourceMode.categoryChildren;
    final hasSourceCategoryId =
        config.sourceCategoryId?.trim().isNotEmpty ?? false;
    final wantsCategoryChildren = isCategoryChildrenMode && hasSourceCategoryId;
    final categoriesAsync =
        wantsCategoryChildren || liveSource == DrawerLiveSource.categories
        ? ref.watch(drawerCategoriesProvider)
        : null;
    final categories = categoriesAsync?.value;
    if ((wantsCategoryChildren || liveSource == DrawerLiveSource.categories) &&
        categories == null &&
        categoriesAsync?.isLoading == true &&
        categoriesAsync?.hasError == false) {
      return CategoryBannerStripSkeleton(
        itemCount: config.skeletonItemCount,
        appearance: config.bannerAppearance.values.toList(growable: false),
      );
    }

    final drawerRootItems = resolveCategoryBannerItems(
      drawerResult: drawer,
      categories: categories,
      includeHidden: false,
      appearanceById: config.bannerAppearance,
    );
    if (!isCategoryChildrenMode) {
      return CategoryBannerStripSection(
        items: drawerRootItems,
        sharedBackgroundMedia: config.sharedBackgroundMedia,
      );
    }

    final childItems = wantsCategoryChildren
        ? resolveCategoryChildrenBannerItems(
            categories: categories,
            parentId: config.sourceCategoryId ?? '',
            includeHidden: false,
            appearanceById: config.bannerAppearance,
          )
        : const <CategoryBannerItem>[];
    if (childItems.isNotEmpty) {
      return CategoryBannerStripSection(
        items: childItems,
        sharedBackgroundMedia: config.sharedBackgroundMedia,
      );
    }

    final fallbackSection = CategoryBannerStripSection(
      items: drawerRootItems,
      sharedBackgroundMedia: config.sharedBackgroundMedia,
    );
    if (!isEditMode) return fallbackSection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const _CategoryChildrenFallbackWarning(), fallbackSection],
    );
  }
}

class _CategoryChildrenFallbackWarning extends StatelessWidget {
  const _CategoryChildrenFallbackWarning();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E5),
          border: Border.all(color: const Color(0xFFE3B872)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Aucune sous-catégorie configurée pour cette catégorie source - '
          'affichage des catégories racines par défaut.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C3D00),
          ),
        ),
      ),
    );
  }
}
