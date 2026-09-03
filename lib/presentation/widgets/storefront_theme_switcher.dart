import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/storefront/storefront_theme.dart';
import '../providers/storefront_theme_providers.dart';

const double storefrontThemeSwitcherCompactNavWidth = 88;
const double storefrontThemeSwitcherLogoSlotWidth = 112;
const _storefrontThemeSwitcherFallbackDiorLabel = 'Luxe';

@visibleForTesting
const Key storefrontThemeSwitcherPillKey = Key(
  'storefront-theme-switcher-pill',
);

typedef StorefrontThemeSelectionCallback =
    Future<void> Function(StorefrontTheme theme);

double storefrontThemeSwitcherWidthForBrandTitle({
  required BuildContext context,
  required String brandTitle,
  required bool isCompact,
  required double minWidth,
  double maxWidth = 200,
}) {
  final direction = Directionality.of(context);
  final horizontalPadding = isCompact ? 4.0 : 8.0;
  final containerPadding = isCompact ? 1.0 : 2.0;
  final sportFontSize = isCompact ? 10.0 : 11.0;
  final diorFontSize = isCompact ? 11.5 : 13.0;
  final sportWidth = _measureSwitcherTextWidth(
    direction: direction,
    label: StorefrontTheme.nike.displayLabel,
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: sportFontSize,
      fontWeight: FontWeight.w700,
      height: 1,
    ),
  );
  final diorWidth = _measureSwitcherTextWidth(
    direction: direction,
    label: storefrontThemeSwitcherDiorLabel(brandTitle),
    style: TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: diorFontSize,
      fontWeight: FontWeight.w700,
      height: 1,
    ),
  );
  final segmentWidth =
      math.max(sportWidth, diorWidth) + (horizontalPadding * 2);
  final desiredWidth = (segmentWidth * 2) + (containerPadding * 2);
  return desiredWidth
      .clamp(minWidth, math.max(minWidth, maxWidth))
      .ceilToDouble();
}

String storefrontThemeSwitcherDiorLabel(String? label) {
  final trimmed = label?.trim() ?? '';
  return trimmed.isEmpty ? _storefrontThemeSwitcherFallbackDiorLabel : trimmed;
}

double _measureSwitcherTextWidth({
  required TextDirection direction,
  required String label,
  required TextStyle style,
}) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    maxLines: 1,
    textDirection: direction,
  )..layout();
  return painter.width;
}

double storefrontThemeSwitcherNavLeadingGap({
  required double contentWidth,
  required double leadingControlsWidth,
  required double logoTextWidth,
  double switcherWidth = storefrontThemeSwitcherCompactNavWidth,
}) {
  final logoLeft = (contentWidth - logoTextWidth) / 2;
  final availableWidth = logoLeft - leadingControlsWidth;
  if (availableWidth <= switcherWidth) return 4;
  return ((availableWidth - switcherWidth) / 2).clamp(4, 36).toDouble();
}

double estimateStorefrontLogoTextWidth({
  required BuildContext context,
  required String title,
  required TextStyle style,
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout(maxWidth: maxWidth);
  return painter.width.clamp(0, maxWidth).toDouble();
}

class StorefrontThemeSwitcher extends ConsumerWidget {
  final Color foregroundColor;
  final bool isCompact;
  final double? width;
  final String? diorLabel;
  final StorefrontThemeSelectionCallback? onThemeSelected;

  /// Drives the selected pill's horizontal position (0 = Sport/Nike,
  /// 1 = Luxe/Dior) so it can follow an interactive page swipe in real time.
  /// Only the pill rebuilds as this animation ticks — the rest of the switcher
  /// (and the navbar around it) is not rebuilt per frame. When null, selection
  /// falls back to a static background on the resolved theme's segment.
  final Animation<double>? visualPosition;

  const StorefrontThemeSwitcher({
    super.key,
    required this.foregroundColor,
    this.isCompact = false,
    this.width,
    this.diorLabel,
    this.onThemeSelected,
    this.visualPosition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(effectiveStorefrontThemeAsyncProvider).value;
    final onDark =
        ThemeData.estimateBrightnessForColor(foregroundColor) ==
        Brightness.light;
    final inactiveForeground = foregroundColor.withValues(alpha: 0.72);
    final selectedBackground = onDark
        ? Colors.white.withValues(alpha: 0.24)
        : const Color(0xFF111111).withValues(alpha: 0.08);
    final borderColor = foregroundColor.withValues(alpha: onDark ? 0.42 : 0.18);
    final height = isCompact ? 24.0 : 30.0;
    final fixedWidth = width != null;
    // A sliding pill needs a fixed width to size/translate against; without one
    // we keep the per-segment selected background.
    final usePill = visualPosition != null && fixedWidth;

    // Text weight/colour follows the resolved theme, not the live pill position,
    // so labels don't snap mid-drag — the sliding pill alone conveys progress.
    final nikeSelected = activeTheme == StorefrontTheme.nike;
    final diorSelected = activeTheme == StorefrontTheme.dior;

    Widget segment(StorefrontTheme theme, {required bool isSelected}) {
      return _ThemeSegment(
        theme: theme,
        label: theme == StorefrontTheme.dior
            ? storefrontThemeSwitcherDiorLabel(diorLabel)
            : theme.displayLabel,
        isCompact: isCompact,
        isSelected: isSelected,
        scaleLabelToFit: fixedWidth,
        foregroundColor: isSelected ? foregroundColor : inactiveForeground,
        // In pill mode the moving pill behind the labels carries the selection.
        selectedBackground: usePill ? Colors.transparent : selectedBackground,
        onTap: () => _setTheme(ref, theme),
      );
    }

    final segmentRow = Row(
      mainAxisSize: fixedWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (fixedWidth)
          Expanded(
            child: segment(StorefrontTheme.nike, isSelected: nikeSelected),
          )
        else
          segment(StorefrontTheme.nike, isSelected: nikeSelected),
        if (fixedWidth)
          Expanded(
            child: segment(StorefrontTheme.dior, isSelected: diorSelected),
          )
        else
          segment(StorefrontTheme.dior, isSelected: diorSelected),
      ],
    );

    final Widget content = usePill
        ? Stack(
            children: [
              // Only this subtree rebuilds per animation tick. Align maps the
              // 0..1 position to a half-width pill (x=-1 left .. x=+1 right).
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: visualPosition!,
                  builder: (context, _) {
                    final pos = visualPosition!.value.clamp(0.0, 1.0);
                    return Align(
                      alignment: Alignment(pos * 2 - 1, 0),
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1,
                        child: DecoratedBox(
                          key: storefrontThemeSwitcherPillKey,
                          decoration: BoxDecoration(
                            color: selectedBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              segmentRow,
            ],
          )
        : segmentRow;

    return Semantics(
      label: 'Changer de thème',
      child: SizedBox(
        width: width,
        height: height,
        child: Container(
          padding: EdgeInsets.all(isCompact ? 1 : 2),
          decoration: BoxDecoration(
            color: foregroundColor.withValues(alpha: onDark ? 0.08 : 0.04),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(999),
          ),
          child: content,
        ),
      ),
    );
  }

  Future<void> _setTheme(WidgetRef ref, StorefrontTheme theme) {
    final callback = onThemeSelected;
    if (callback != null) return callback(theme);
    return writeVisitorStorefrontThemeOverride(ref, theme);
  }
}

class _ThemeSegment extends StatelessWidget {
  final StorefrontTheme theme;
  final String label;
  final bool isCompact;
  final bool isSelected;
  final bool scaleLabelToFit;
  final Color foregroundColor;
  final Color selectedBackground;
  final VoidCallback onTap;

  const _ThemeSegment({
    required this.theme,
    required this.label,
    required this.isCompact,
    required this.isSelected,
    required this.scaleLabelToFit,
    required this.foregroundColor,
    required this.selectedBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isCompact ? 4.0 : 8.0;
    final verticalPadding = isCompact ? 2.0 : 4.0;
    final fontSize = switch (theme) {
      StorefrontTheme.nike => isCompact ? 10.0 : 11.0,
      StorefrontTheme.dior => isCompact ? 11.5 : 13.0,
    };
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        fontFamily: switch (theme) {
          StorefrontTheme.nike => 'Inter',
          StorefrontTheme.dior => 'CormorantGaramond',
        },
        color: foregroundColor,
        fontSize: fontSize,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        height: 1,
      ),
    );

    return Material(
      color: isSelected ? selectedBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: scaleLabelToFit
                ? FittedBox(fit: BoxFit.scaleDown, child: text)
                : text,
          ),
        ),
      ),
    );
  }
}
