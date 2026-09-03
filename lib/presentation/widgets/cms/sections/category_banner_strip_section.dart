import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/cms/cms_models.dart';
import '../../../../application/navigation/drawer_navigation_models.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/navigation_providers.dart';
import '../../kiki_image.dart';
import '../../storefront_layout.dart';
import '../../landing_asset_loading_backdrop.dart';
import '../../scroll_directional_glow.dart';
import '../../vertical_parallax.dart';
import '../cms_hex_color.dart';
import '../cms_href.dart';
import '../cms_legacy_l10n.dart';
import 'category_banner_strip_resolver.dart';

/// Stack of full-bleed banners (Chaussures / Vêtements / Sport in the
/// Nike reference). Each banner has a large left-aligned title over a dark
/// background, with an image bleeding from the right.
///
/// Pure visual widget: it does not know where its items come from. The host
/// (`CategoryBannerStripSectionHost`) resolves them from the live drawer
/// and passes the result here.
class CategoryBannerStripSection extends StatelessWidget {
  final List<CategoryBannerItem> items;
  final CmsMediaRef? sharedBackgroundMedia;

  const CategoryBannerStripSection({
    super.key,
    required this.items,
    this.sharedBackgroundMedia,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final size = MediaQuery.sizeOf(context);
    final isMobile = StorefrontLayout.isMobile(size.width);
    final bannerHeight = _categoryBannerHeightFor(size);
    final sharedBackgroundCount =
        sharedBackgroundMedia != null && sharedBackgroundMedia!.isUsable
        ? (items.length < 3 ? items.length : 3)
        : 0;
    return Padding(
      padding: EdgeInsets.only(top: isMobile ? 20 : 24, bottom: 8),
      child: Column(
        children: [
          if (sharedBackgroundCount > 0)
            _SharedBackgroundBannerGroup(
              items: items.take(sharedBackgroundCount).toList(growable: false),
              media: sharedBackgroundMedia!,
              bannerHeight: bannerHeight,
            ),
          if (sharedBackgroundCount > 0 && sharedBackgroundCount < items.length)
            const SizedBox(height: 4),
          for (var i = sharedBackgroundCount; i < items.length; i++) ...[
            _CategoryBanner(item: items[i], height: bannerHeight),
            if (i < items.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class CategoryBannerStripSkeleton extends StatelessWidget {
  final int itemCount;
  final List<CategoryBannerAppearance> appearance;

  const CategoryBannerStripSkeleton({
    super.key,
    this.itemCount = 2,
    this.appearance = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) {
      return const SizedBox.shrink();
    }
    final size = MediaQuery.sizeOf(context);
    final isMobile = StorefrontLayout.isMobile(size.width);
    final bannerHeight = _categoryBannerHeightFor(size);
    return ExcludeSemantics(
      child: LandingGradientLoadingSurface(
        child: Padding(
          padding: EdgeInsets.only(top: isMobile ? 20 : 24, bottom: 8),
          child: Column(
            children: [
              for (var i = 0; i < itemCount; i++) ...[
                _CategoryBannerSkeleton(
                  height: bannerHeight,
                  appearance: i < appearance.length ? appearance[i] : null,
                ),
                if (i < itemCount - 1) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedBackgroundBannerGroup extends StatelessWidget {
  final List<CategoryBannerItem> items;
  final CmsMediaRef media;
  final double bannerHeight;

  const _SharedBackgroundBannerGroup({
    required this.items,
    required this.media,
    required this.bannerHeight,
  });

  @override
  Widget build(BuildContext context) {
    final groupHeight =
        (bannerHeight * items.length) + (4 * (items.length - 1));

    // Vertical parallax: the shared image drifts as the landing scrolls, behind
    // the fixed titles and dividers. Skipped under reduced motion and when there
    // is no enclosing Scrollable. overscan adds the vertical slack to pan
    // within, since the 4:3 source barely overflows the near-square group box.
    Widget background = KikiImage(
      imageUrl: media.thumbUrl(size: '1600x1200f'),
      fit: BoxFit.cover,
      placeholder: const SizedBox.shrink(),
      errorWidget: const SizedBox.shrink(),
    );
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null && !MediaQuery.disableAnimationsOf(context)) {
      background = VerticalParallax(
        scrollable: scrollable,
        overscan: 1.22,
        child: background,
      );
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: groupHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xCC000000),
                    Color(0x66000000),
                    Color(0x26000000),
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _SharedBackgroundBanner(
                    item: items[i],
                    height: bannerHeight,
                    // Volumetric light scattering only on the first banner; its
                    // rays radiate across the whole banner surface.
                    glow: i == 0,
                  ),
                  if (i < items.length - 1)
                    Container(height: 4, color: const Color(0xE6000000)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedBackgroundBanner extends ConsumerStatefulWidget {
  final CategoryBannerItem item;
  final double height;
  final bool glow;

  const _SharedBackgroundBanner({
    required this.item,
    required this.height,
    this.glow = false,
  });

  @override
  ConsumerState<_SharedBackgroundBanner> createState() =>
      _SharedBackgroundBannerState();
}

class _SharedBackgroundBannerState
    extends ConsumerState<_SharedBackgroundBanner> {
  // Vivid scan light: a yellow-green core fading to cyan with distance, à la
  // the "Let it Glow!" reference, so the rays read over the banner imagery.
  static const Color _lightColor = Color(0xFFCCFF00);
  static const Color _falloffColor = Color(0xFF66FFFF);
  static const Duration _sweepPeriod = Duration(seconds: 1);

  // A tap runs the scan first, then the banner's action (e.g. open the drawer).
  bool _playing = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    // Warm the noise so the tap-triggered scan starts instantly.
    if (widget.glow) ScrollDirectionalGlow.warmUp();
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (_playing) return;
    // No glow on this banner, or reduced motion: act immediately.
    if (!widget.glow || MediaQuery.disableAnimationsOf(context)) {
      _runAction();
      return;
    }
    setState(() => _playing = true);
    // Safety net so a glow hiccup can never block the navigation.
    _fallback = Timer(
      _sweepPeriod + const Duration(milliseconds: 300),
      _finish,
    );
  }

  void _finish() {
    if (!_playing) return;
    _fallback?.cancel();
    _fallback = null;
    setState(() => _playing = false);
    _runAction();
  }

  void _runAction() {
    _handleCategoryBannerTap(context, ref, widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = isMobile
        ? StorefrontLayout.nikeContentPaddingFor(width)
        : 24.0;
    final title = localizedLegacyCmsText(context, widget.item.title);
    final textStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: isMobile ? 22 : 30,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: Colors.white,
    );

    // The title pinned to the same spot, used both as the bright scatter source
    // (glyphs) and the crisp legible copy on top.
    Widget label(Widget child) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 20,
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The 1s scan runs only while a tap is in flight; when it finishes
              // the banner's action fires.
              if (widget.glow && _playing)
                Positioned.fill(
                  child: ScrollDirectionalGlow(
                    sweep: true,
                    sweepPeriod: _sweepPeriod,
                    onSweepComplete: _finish,
                    // The scan travels exactly across the glyphs (left padding
                    // → end of the measured title).
                    sweepFromPx: horizontalPadding,
                    sweepToPx:
                        horizontalPadding +
                        _titleWidth(context, title, textStyle),
                    glowColor: _lightColor,
                    falloffColor: _falloffColor,
                    falloff: 1.3,
                    density: 0.9,
                    lightStrength: 2.0,
                    weight: 0.2,
                    glowStrength: 2.4,
                    child: label(
                      GlyphGlowSource(text: title, style: textStyle),
                    ),
                  ),
                ),
              label(Text(title, style: textStyle)),
            ],
          ),
        ),
      ),
    );
  }

  static double _titleWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}

class _CategoryBanner extends ConsumerWidget {
  final CategoryBannerItem item;
  final double height;

  const _CategoryBanner({required this.item, required this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradientStart = cmsColorFromHex(item.gradientStartHex);
    final gradientEnd = cmsColorFromHex(item.gradientEndHex);
    final isLight = item.backgroundTone == 'light';
    // A single custom color paints flat; two paint a left→right gradient.
    final bg =
        gradientStart ??
        gradientEnd ??
        (isLight ? const Color(0xFFEDEAE3) : const Color(0xFF2A3038));
    final gradient = gradientStart != null && gradientEnd != null
        ? LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [gradientStart, gradientEnd],
          )
        : null;
    final textColor = gradientStart != null || gradientEnd != null
        ? (bg.computeLuminance() > 0.5 ? const Color(0xFF111111) : Colors.white)
        : (isLight ? const Color(0xFF111111) : Colors.white);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = isMobile
        ? StorefrontLayout.nikeContentPaddingFor(width)
        : 24.0;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: bg, gradient: gradient),
        child: InkWell(
          onTap: () => _handleCategoryBannerTap(context, ref, item),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                if (item.media != null && item.media!.isUsable)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: MediaQuery.sizeOf(context).width * 0.6,
                    child: ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [bg, bg.withValues(alpha: 0)],
                        stops: const [0.0, 0.4],
                      ).createShader(rect),
                      blendMode: BlendMode.dstOut,
                      child: KikiImage(
                        imageUrl: item.media!.thumbUrl(size: '900x500f'),
                        fit: BoxFit.cover,
                        placeholder: const SizedBox.shrink(),
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      localizedLegacyCmsText(context, item.title),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: isMobile ? 22 : 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: textColor,
                      ),
                    ),
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

void _handleCategoryBannerTap(
  BuildContext context,
  WidgetRef ref,
  CategoryBannerItem item,
) {
  // When the banner maps to a category/nav node that has sub-categories,
  // open the drawer already drilled into that node's children. Otherwise
  // (no mapping, or the target has no children to show) fall back to PLP
  // navigation via the banner href.
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold != null && _drillTargetHasChildren(ref, item)) {
    ref.read(pendingDrawerDrillTargetProvider.notifier).state =
        DrawerDrillTarget(categoryId: item.categoryId, nodeId: item.nodeId);
    scaffold.openDrawer();
    return;
  }
  if (item.href.isNotEmpty) {
    launchCmsHref(context, item.href);
  }
}

/// Reads the live drawer data to decide whether drilling will land on a node
/// that actually has children. Only reads the categories provider when the
/// drawer is in category-fallback mode (managed mode never needs it). The
/// pure decision lives in [categoryBannerDrillHasChildren].
bool _drillTargetHasChildren(WidgetRef ref, CategoryBannerItem item) {
  // No mapping to drill into: skip reading the drawer providers entirely.
  if (item.categoryId == null && item.nodeId == null) {
    return false;
  }
  final drawer = ref.read(mainDrawerNavigationProvider).value;
  final isManaged =
      drawer != null &&
      drawer.menu?.liveSource != DrawerLiveSource.categories &&
      drawer.isUsable;
  final categories = (drawer != null && !isManaged)
      ? ref.read(drawerCategoriesProvider).value
      : null;
  return categoryBannerDrillHasChildren(
    item: item,
    drawerResult: drawer,
    categories: categories,
  );
}

class _CategoryBannerSkeleton extends StatelessWidget {
  final double height;
  final CategoryBannerAppearance? appearance;

  const _CategoryBannerSkeleton({required this.height, this.appearance});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = isMobile
        ? StorefrontLayout.nikeContentPaddingFor(width)
        : 24.0;
    final gradientStart = cmsColorFromHex(appearance?.gradientStartHex);
    final gradientEnd = cmsColorFromHex(appearance?.gradientEndHex);
    // The animated landing shader is the loading surface. CMS appearance
    // colors remain as a very light tint so they do not paint an opaque block
    // over it and make the loading state look identical to the old skeleton.
    final bg = (gradientStart ?? gradientEnd)?.withValues(alpha: 0.12);
    final gradient = gradientStart != null && gradientEnd != null
        ? LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              gradientStart.withValues(alpha: 0.12),
              gradientEnd.withValues(alpha: 0.12),
            ],
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(color: bg, gradient: gradient),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 20,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: isMobile ? 156 : 230,
              height: isMobile ? 30 : 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _categoryBannerHeightFor(Size size) {
  final isMobile = StorefrontLayout.isMobile(size.width);
  final bannerHeight = isMobile ? size.width * 0.28 : size.height * 0.22;
  return isMobile
      ? bannerHeight.clamp(108.0, 132.0).toDouble()
      : bannerHeight.clamp(160.0, 220.0).toDouble();
}
