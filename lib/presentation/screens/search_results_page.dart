import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../../application/catalog/search_query.dart';
import '../../application/storefront/storefront_plp_profile.dart';
import '../../application/storefront/storefront_theme.dart';
import '../l10n/l10n_extension.dart';
import '../providers/content_locale_provider.dart';
import '../providers/search_providers.dart';
import '../providers/storefront_theme_providers.dart';
import '../widgets/error_display.dart';
import '../widgets/product_card.dart';
import '../widgets/storefront_layout.dart';
import 'product_list_page.dart' show kSportChildAspectRatio, kSportGridSpacing;

/// Localized label for a search sort option, resolved at the render site so the
/// [SearchSort] enum stays free of UI strings.
String searchSortLabel(BuildContext context, SearchSort sort) => switch (sort) {
  SearchSort.newest => context.l10n.searchSortNewest,
  SearchSort.nameAsc => context.l10n.searchSortNameAsc,
  SearchSort.nameDesc => context.l10n.searchSortNameDesc,
};

class SearchResultsPage extends ConsumerWidget {
  final SearchQuery query;

  const SearchResultsPage({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider(query));
    final locale = ref.watch(contentLocaleProvider);
    final results = resultsAsync.value;
    final isRefreshing = resultsAsync.isLoading && results != null;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Mirror the PLP layout for the active apparence so a Nike-themed search
    // reads as the dense sport grid (and reuses the same product cards + Hero
    // PLP→PDP transition) rather than a separate editorial grid.
    final theme =
        ref.watch(effectiveStorefrontThemeAsyncProvider).value ??
        StorefrontTheme.fallback;
    final profile = StorefrontPlpProfile.forTheme(theme);
    final isSport = profile.presentation == PlpPresentation.sportPerformance;
    final sportEdgeToEdge = isSport && StorefrontLayout.isMobile(screenWidth);
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

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SearchHeader(
            queryText: query.query,
            currentSort: query.sort,
            totalItems: results?.totalItems,
            onSortChanged: (sort) {
              context.go(
                CatalogRoutes.localizedLocation(
                  CatalogRoutes.searchUrl(query: query.query ?? '', sort: sort),
                  locale: locale,
                ),
              );
            },
          ),
        ),
        if (isRefreshing)
          const SliverToBoxAdapter(child: LinearProgressIndicator()),
        if (results != null) ...[
          if (query.query == null || query.query!.trim().isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  context.l10n.searchPrompt,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else if (results.items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  context.l10n.searchEmptyResults(query.query ?? ''),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            SliverMainAxisGroup(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = results.items[index];
                      return ProductCard(
                        product: item.product,
                        prices: item.prices,
                        routeName: CatalogRoutes.productById(item.product.id),
                        enableHeroTransition: true,
                        presentation: profile.productCardPresentation,
                      );
                    }, childCount: results.items.length),
                  ),
                ),
                if (results.totalPages > 1)
                  SliverToBoxAdapter(
                    child: _PaginationControls(
                      currentPage: results.page,
                      totalPages: results.totalPages,
                      onPageChanged: (newPage) {
                        context.go(
                          CatalogRoutes.localizedLocation(
                            CatalogRoutes.searchUrl(
                              query: query.query ?? '',
                              sort: query.sort,
                              page: newPage,
                            ),
                            locale: locale,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ] else if (resultsAsync.hasError)
          SliverFillRemaining(
            child: ErrorDisplay(
              error: resultsAsync.error!,
              onRetry: () => ref.invalidate(searchResultsProvider(query)),
            ),
          )
        else
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final String? queryText;
  final SearchSort currentSort;
  final int? totalItems;
  final ValueChanged<SearchSort> onSortChanged;

  const _SearchHeader({
    required this.queryText,
    required this.currentSort,
    required this.totalItems,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = StorefrontLayout.isTabletOnly(screenWidth);
    final isDesktop = StorefrontLayout.isDesktop(screenWidth);

    final hasQuery = queryText != null && queryText!.trim().isNotEmpty;

    return StorefrontPageSection(
      maxWidth: StorefrontLayout.productListMaxWidth,
      padding: EdgeInsets.only(
        top: isDesktop ? 8 : (isTablet ? 6 : 4),
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasQuery
                ? context.l10n.searchTitleWithQuery(queryText!)
                : context.l10n.searchTitle,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 30 : 26),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2F2F2C),
              height: 1.08,
            ),
          ),
          const SizedBox(height: 12),
          if (isTablet || isDesktop)
            Row(
              children: [
                if (hasQuery)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${totalItems ?? '...'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F2F2C),
                          ),
                        ),
                        TextSpan(
                          text: context.l10n.searchResultCountSuffix(
                            totalItems ?? 0,
                          ),
                          style: const TextStyle(color: Color(0xFF7B7F82)),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                const Spacer(),
                if (hasQuery)
                  _SortDropdown(
                    currentSort: currentSort,
                    onChanged: onSortChanged,
                  ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasQuery)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${totalItems ?? '...'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2F2F2C),
                          ),
                        ),
                        TextSpan(
                          text: context.l10n.searchResultCountSuffix(
                            totalItems ?? 0,
                          ),
                          style: const TextStyle(color: Color(0xFF7B7F82)),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                if (hasQuery) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _SortDropdown(
                      currentSort: currentSort,
                      onChanged: onSortChanged,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final SearchSort currentSort;
  final ValueChanged<SearchSort> onChanged;

  const _SortDropdown({required this.currentSort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE6E3DD), width: 1.2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SearchSort>(
          value: currentSort,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF2F2F2C)),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2F2F2C),
          ),
          items: SearchSort.values
              .map(
                (sort) => DropdownMenuItem(
                  value: sort,
                  child: Text(searchSortLabel(context, sort)),
                ),
              )
              .toList(),
          onChanged: (sort) {
            if (sort != null) onChanged(sort);
          },
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            color: const Color(0xFF2F2F2C),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.searchPagination(currentPage, totalPages),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F2F2C),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: const Color(0xFF2F2F2C),
          ),
        ],
      ),
    );
  }
}
