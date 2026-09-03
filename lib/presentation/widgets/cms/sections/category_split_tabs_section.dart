import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/catalog_routes.dart';
import '../../../../app/locale_route_resolver.dart';
import '../../../../application/cms/cms_models.dart';
import '../../../../application/storefront/storefront_navigation_settings.dart';
import '../../../../application/storefront/storefront_sport_segment.dart';
import '../../../../domain/catalog/catalog_entities.dart';
import '../../../providers/category_providers.dart';
import '../../storefront_layout.dart';
import '../cms_legacy_l10n.dart';
import '../cms_href.dart';

final _categorySplitDisplayModeSessionProvider =
    StateProvider<CategorySplitDisplayMode?>((ref) => null);

/// Nike-style underlined tab row (Homme / Femme / Enfant).
///
class CategorySplitTabsSection extends ConsumerWidget {
  final CategorySplitTabsConfig config;
  final StorefrontSportSegment? activeSportSegment;

  const CategorySplitTabsSection({
    super.key,
    required this.config,
    this.activeSportSegment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tabs ↔ expansible design is a global navigation setting, so it stays
    // consistent across every sport segment landing (Homme/Femme/Enfant).
    final navigationSettings = ref.watch(
      storefrontNavigationSettingsProvider.select((async) => async.value),
    );
    final sessionDisplayMode = ref.watch(
      _categorySplitDisplayModeSessionProvider,
    );
    final displayMode = _displayModeFor(
      config,
      navigationSettings,
      sessionDisplayMode,
    );

    if (displayMode == CategorySplitDisplayMode.expansible) {
      final title = config.expansibleTitle?.trim();
      return _CategorySplitExpansible(
        title: title == null || title.isEmpty
            ? localizedLegacyCmsText(context, 'Parcourir')
            : localizedLegacyCmsText(context, title),
        activeSportSegment: activeSportSegment,
        onBeforeSegmentNavigate: () {
          ref.read(_categorySplitDisplayModeSessionProvider.notifier).state =
              CategorySplitDisplayMode.expansible;
        },
      );
    }

    if (config.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = StorefrontLayout.nikeContentPaddingFor(width);
    final activeIndex = _activeIndex();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        isMobile ? 24 : 32,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (var i = 0; i < config.items.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == config.items.length - 1 ? 0 : 24,
                ),
                child: _TabLabel(
                  item: config.items[i],
                  isActive: i == activeIndex,
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _activeIndex() {
    final segment = activeSportSegment;
    if (segment == null) return config.defaultActiveIndex;

    for (var i = 0; i < config.items.length; i++) {
      if (_normalizedSegment(config.items[i].segment) == segment.wireName) {
        return i;
      }
    }
    for (var i = 0; i < config.items.length; i++) {
      if (_hrefMatchesSegment(config.items[i].href, segment)) {
        return i;
      }
    }
    return config.defaultActiveIndex;
  }
}

CategorySplitDisplayMode _displayModeFor(
  CategorySplitTabsConfig config,
  StorefrontNavigationSettings? navigationSettings,
  CategorySplitDisplayMode? sessionDisplayMode,
) {
  if (navigationSettings?.hasCategorySplitDisplayMode == true) {
    return navigationSettings!.categorySplitDisplayMode;
  }
  return CategorySplitDisplayMode.tryParse(config.displayMode) ??
      sessionDisplayMode ??
      CategorySplitDisplayMode.tabs;
}

String? _normalizedSegment(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _hrefMatchesSegment(String href, StorefrontSportSegment segment) {
  final normalized = _normalizedHref(href);
  if (normalized == null) return false;
  if (segment == StorefrontSportSegment.homme && normalized == '/') {
    return true;
  }
  return normalized == CatalogRoutes.sportSegmentLocation(segment);
}

String? _normalizedHref(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  final path = uri?.path.trim().isNotEmpty == true
      ? resolveLocaleRoute(uri!).routePath
      : trimmed;
  if (path == '/') return '/';
  return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

// `easeReverse`: pair an expressive opening ease with a calmer closing one.
// Replaying an overshoot curve in reverse reads as an awkward backward kick, so
// the collapse runs a *separate*, smooth curve — the same idea as GSAP's
// `easeReverse`. `Expansible` shares a single duration across both directions
// (it ignores `reverseDuration`), so the snappier "exit" is expressed through
// the reverse curve rather than a shorter time.
const Duration _expansibleOpenDuration = Duration(milliseconds: 340);
const Duration _expansibleReducedDuration = Duration(milliseconds: 150);

const Curve _panelOpenCurve = Curves.easeOutCubic;
const Curve _panelCloseCurve = Curves.easeInOutCubic;
// The chevron springs ~10° past 180° on open, then rotates smoothly back.
const Curve _chevronOpenCurve = Curves.easeOutBack;
const Curve _chevronCloseCurve = Curves.easeInOutCubic;
// Reduced motion drops the overshoot/spring; both directions ease plainly.
const Curve _reducedMotionCurve = Curves.easeOut;

/// `displayMode == 'expansible'`: a collapsible header that reveals, inline, a
/// Nike-style menu — the segments (HOMME/FEMME/ENFANT top-level categories) stay
/// visible as a switcher and the selected segment's categories + sub-categories
/// show simultaneously below (see [_CategorySplitMenu]).
class _CategorySplitExpansible extends StatefulWidget {
  final String title;
  final StorefrontSportSegment? activeSportSegment;
  final VoidCallback onBeforeSegmentNavigate;

  const _CategorySplitExpansible({
    required this.title,
    this.activeSportSegment,
    required this.onBeforeSegmentNavigate,
  });

  @override
  State<_CategorySplitExpansible> createState() =>
      _CategorySplitExpansibleState();
}

class _CategorySplitExpansibleState extends State<_CategorySplitExpansible> {
  final ExpansibleController _controller = ExpansibleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isExpanded) {
      _controller.collapse();
    } else {
      _controller.expand();
    }
    setState(() {}); // refresh header chevron
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = StorefrontLayout.isMobile(size.width);
    final horizontalPadding = StorefrontLayout.nikeContentPaddingFor(
      size.width,
    );

    // Gate the spring/overshoot on reduced motion (project convention).
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final chevronOpenCurve = reduceMotion
        ? _reducedMotionCurve
        : _chevronOpenCurve;
    final chevronCloseCurve = reduceMotion
        ? _reducedMotionCurve
        : _chevronCloseCurve;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        isMobile ? 24 : 32,
      ),
      child: Expansible(
        controller: _controller,
        // Build the menu (and its category read) only while expanded.
        maintainState: false,
        // easeReverse: an expressive open, a calmer close (see the curve
        // constants above).
        animationStyle: AnimationStyle(
          duration: reduceMotion
              ? _expansibleReducedDuration
              : _expansibleOpenDuration,
          curve: reduceMotion ? _reducedMotionCurve : _panelOpenCurve,
          reverseCurve: reduceMotion ? _reducedMotionCurve : _panelCloseCurve,
        ),
        headerBuilder: (context, animation) => _ExpansibleHeader(
          // Collapsed: show the active segment (e.g. "Femme"); expanded: the
          // configured title (e.g. "Parcourir").
          title: _controller.isExpanded
              ? widget.title
              : (widget.activeSportSegment == null
                    ? widget.title
                    : localizedSportSegmentLabel(
                        context,
                        widget.activeSportSegment!,
                      )),
          animation: animation,
          openCurve: chevronOpenCurve,
          closeCurve: chevronCloseCurve,
          onTap: _toggle,
        ),
        bodyBuilder: (context, animation) => _CategorySplitMenu(
          activeSportSegment: widget.activeSportSegment,
          onBeforeNavigate: _controller.collapse,
          onBeforeSegmentNavigate: widget.onBeforeSegmentNavigate,
        ),
      ),
    );
  }
}

/// Inline menu: the segments (HOMME/FEMME/ENFANT top-level categories) stay
/// visible as a switcher; the **active** segment is checked and its categories +
/// sub-categories show simultaneously below. Tapping a segment collapses and
/// navigates to that segment's landing (`/sport/<segment>`), exactly like the
/// tabs design; tapping a (sub-)category collapses and opens its PLP.
class _CategorySplitMenu extends ConsumerWidget {
  final StorefrontSportSegment? activeSportSegment;
  final VoidCallback onBeforeNavigate;
  final VoidCallback onBeforeSegmentNavigate;

  const _CategorySplitMenu({
    required this.activeSportSegment,
    required this.onBeforeNavigate,
    required this.onBeforeSegmentNavigate,
  });

  static String? _normalizeParentId(String? parentId) {
    final trimmed = parentId?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _activeSegmentId(List<CatalogCategory> segments) {
    final segment = activeSportSegment;
    if (segment != null) {
      for (final s in segments) {
        if (s.slug?.trim().toLowerCase() == segment.wireName) return s.id;
      }
    }
    return segments.isEmpty ? null : segments.first.id;
  }

  void _openSegment(BuildContext context, CatalogCategory segment) {
    onBeforeSegmentNavigate();
    onBeforeNavigate();
    final sport = StorefrontSportSegment.tryParse(segment.slug);
    final href = sport != null
        ? CatalogRoutes.sportSegmentLocation(sport)
        : CatalogRoutes.categoryLocation(segment);
    launchCmsHref(context, href);
  }

  void _openCategory(BuildContext context, CatalogCategory category) {
    onBeforeNavigate();
    launchCmsHref(context, CatalogRoutes.categoryLocation(category));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(drawerCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) {
        final byParent = <String, List<CatalogCategory>>{};
        final ids = {for (final c in categories) c.id};
        final segments = <CatalogCategory>[];
        for (final category in categories) {
          final parentId = _normalizeParentId(category.parentId);
          if (parentId == null || !ids.contains(parentId)) {
            segments.add(category);
          } else {
            byParent.putIfAbsent(parentId, () => []).add(category);
          }
        }
        if (segments.isEmpty) return const SizedBox.shrink();

        final activeId = _activeSegmentId(segments);
        final activeChildren = activeId == null
            ? const <CatalogCategory>[]
            : (byParent[activeId] ?? const <CatalogCategory>[]);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final segment in segments)
              _SegmentRow(
                label: _segmentLabel(context, segment),
                isSelected: segment.id == activeId,
                onTap: () => _openSegment(context, segment),
              ),
            if (activeChildren.isNotEmpty) ...[
              const Divider(height: 28, color: Color(0xFFE6E4DE)),
              for (final category in activeChildren) ...[
                _CategoryRow(
                  label: localizedLegacyCmsText(context, category.name),
                  emphasized: true,
                  onTap: () => _openCategory(context, category),
                ),
                for (final sub
                    in (byParent[category.id] ?? const <CatalogCategory>[]))
                  _CategoryRow(
                    label: localizedLegacyCmsText(context, sub.name),
                    emphasized: false,
                    indented: true,
                    onTap: () => _openCategory(context, sub),
                  ),
              ],
            ],
          ],
        );
      },
    );
  }
}

String _segmentLabel(BuildContext context, CatalogCategory segment) {
  final sport = StorefrontSportSegment.tryParse(segment.slug);
  if (sport != null) return localizedSportSegmentLabel(context, sport);
  return localizedLegacyCmsText(context, segment.name);
}

class _SegmentRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 22, color: Color(0xFF111111)),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final bool emphasized;
  final bool indented;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.label,
    required this.emphasized,
    required this.onTap,
    this.indented = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indented ? 16 : 0, 10, 0, 10),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: emphasized ? 17 : 15,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            color: emphasized
                ? const Color(0xFF111111)
                : const Color(0xFF5F5D57),
          ),
        ),
      ),
    );
  }
}

class _ExpansibleHeader extends StatefulWidget {
  final String title;
  final Animation<double> animation;
  final Curve openCurve;
  final Curve closeCurve;
  final VoidCallback onTap;

  const _ExpansibleHeader({
    required this.title,
    required this.animation,
    required this.openCurve,
    required this.closeCurve,
    required this.onTap,
  });

  @override
  State<_ExpansibleHeader> createState() => _ExpansibleHeaderState();
}

class _ExpansibleHeaderState extends State<_ExpansibleHeader> {
  // The header builder receives the raw (linear) controller, so the chevron is
  // curved here. `CurvedAnimation` applies [openCurve] while expanding and
  // [closeCurve] while collapsing — the easeReverse split that keeps the spring
  // out of the exit.
  late CurvedAnimation _chevron;

  @override
  void initState() {
    super.initState();
    _chevron = CurvedAnimation(
      parent: widget.animation,
      curve: widget.openCurve,
      reverseCurve: widget.closeCurve,
    );
  }

  @override
  void didUpdateWidget(covariant _ExpansibleHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      _chevron.dispose();
      _chevron = CurvedAnimation(
        parent: widget.animation,
        curve: widget.openCurve,
        reverseCurve: widget.closeCurve,
      );
      return;
    }
    if (widget.openCurve != oldWidget.openCurve) {
      _chevron.curve = widget.openCurve;
    }
    if (widget.closeCurve != oldWidget.closeCurve) {
      _chevron.reverseCurve = widget.closeCurve;
    }
  }

  @override
  void dispose() {
    _chevron.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(width: 6),
            RotationTransition(
              turns: _chevron.drive(Tween<double>(begin: 0, end: 0.5)),
              child: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final CategorySplitTabItem item;
  final bool isActive;

  const _TabLabel({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.href.isNotEmpty) launchCmsHref(context, item.href);
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF111111) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          _tabLabel(context, item),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF111111) : const Color(0xFF8E8E8E),
          ),
        ),
      ),
    );
  }
}

String _tabLabel(BuildContext context, CategorySplitTabItem item) {
  final segment = StorefrontSportSegment.tryParse(item.segment);
  if (segment != null) return localizedSportSegmentLabel(context, segment);
  return localizedLegacyCmsText(context, item.label);
}
