import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/app_providers.dart';
import '../../../../application/cms/cms_models.dart';
import '../../../../application/storefront/storefront_brand_settings.dart';
import '../../kiki_image.dart';
import '../../storefront_layout.dart';
import '../../storefront_theme_switcher.dart';
import '../cms_href.dart';

/// Compact pill segmented control. Existing CMS payloads keep link navigation;
/// `themeSwitcher` payloads persist a local Sport/Luxe visitor choice.
class BrandSegmentSection extends ConsumerWidget {
  final BrandSegmentConfig config;

  const BrandSegmentSection({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (config.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isThemeSwitcher = config.mode == BrandSegmentMode.themeSwitcher;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = StorefrontLayout.nikeContentPaddingFor(width);
    final brandSettingsAsync = ref.watch(storefrontBrandSettingsProvider);
    final brandSettings =
        brandSettingsAsync.value ?? StorefrontBrandSettings.fallback;

    if (isThemeSwitcher) {
      final switcherWidth = storefrontThemeSwitcherWidthForBrandTitle(
        context: context,
        brandTitle: brandSettings.title,
        isCompact: true,
        minWidth: storefrontThemeSwitcherCompactNavWidth,
      );
      final switcherLeft = _themeSwitcherNavLeftFor(
        context: context,
        brandTitle: brandSettings.title,
        switcherWidth: switcherWidth,
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(
          switcherLeft,
          isMobile ? 8 : 16,
          horizontalPadding,
          isMobile ? 32 : 40,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: StorefrontThemeSwitcher(
            foregroundColor: Color(0xFF111111),
            isCompact: true,
            width: switcherWidth,
            diorLabel: brandSettings.title,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isMobile ? 8 : 16,
        horizontalPadding,
        isMobile ? 32 : 40,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEE7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < config.items.length; i++)
                _BrandSegmentChip(
                  item: config.items[i],
                  isActive: i == config.activeIndex,
                  isCompact: isMobile,
                  onTap: () {
                    final href = config.items[i].href;
                    if (href.isNotEmpty) launchCmsHref(context, href);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _themeSwitcherNavLeftFor({
  required BuildContext context,
  required String brandTitle,
  required double switcherWidth,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final isTablet = StorefrontLayout.isTabletOnly(width);
  final isDesktop = StorefrontLayout.isDesktop(width);
  final isMobile = !isTablet && !isDesktop;
  final useExpandedMobile = isMobile;
  final logoSize = isDesktop
      ? 28.0
      : (isTablet ? 26.0 : (useExpandedMobile ? 30.0 : 20.0));
  final logoMaxWidth = isDesktop ? 320.0 : (isTablet ? 260.0 : 200.0);
  final horizontalPadding = isDesktop ? 24.0 : (useExpandedMobile ? 6.0 : 14.0);
  final iconButtonWidth = useExpandedMobile ? 38.0 : 48.0;
  final renderedIconSlotWidth = 40.0;
  final sidePadding = StorefrontLayout.outerPaddingFor(
    width,
    maxWidth: 1440,
    minHorizontalPadding: horizontalPadding,
  );
  final contentWidth = width - (sidePadding * 2);
  final logoTextWidth = estimateStorefrontLogoTextWidth(
    context: context,
    title: brandTitle,
    style: GoogleFonts.cormorantGaramond(
      fontSize: logoSize,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1,
    ),
    maxWidth: logoMaxWidth,
  );
  final leadingControlsWidth = iconButtonWidth * (isMobile ? 2 : 1);
  final renderedLeadingControlsWidth =
      renderedIconSlotWidth * (isMobile ? 2 : 1);
  final leadingGap = storefrontThemeSwitcherNavLeadingGap(
    contentWidth: contentWidth,
    leadingControlsWidth: leadingControlsWidth,
    logoTextWidth: logoTextWidth,
    switcherWidth: switcherWidth,
  );
  return sidePadding + renderedLeadingControlsWidth + leadingGap;
}

class _BrandSegmentChip extends StatelessWidget {
  final BrandSegmentItem item;
  final bool isActive;
  final bool isCompact;
  final VoidCallback? onTap;

  const _BrandSegmentChip({
    required this.item,
    required this.isActive,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.white : Colors.transparent,
      elevation: isActive ? 0.5 : 0,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 18,
            vertical: 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.media != null && item.media!.isUsable) ...[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: KikiImage(
                    imageUrl: item.media!.thumbUrl(size: '64x64f'),
                    fit: BoxFit.contain,
                    placeholder: const SizedBox.shrink(),
                    errorWidget: const SizedBox.shrink(),
                  ),
                ),
                if (item.label.isNotEmpty) const SizedBox(width: 6),
              ],
              if (item.label.isNotEmpty)
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFF111111)
                        : const Color(0xFF8E8E8E),
                    height: 1.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
