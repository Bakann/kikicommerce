import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/app_providers.dart';
import '../../../app/catalog_routes.dart';
import '../../../application/storefront/storefront_brand_settings.dart';
import '../../../application/storefront/storefront_navigation_settings.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers/cart_provider.dart';
import '../../providers/edit_mode_provider.dart';
import '../customer_account_modal.dart';
import '../storefront_layout.dart';
import '../storefront_brand_editor_dialog.dart';
import '../storefront_drawer_external_link_stub.dart'
    if (dart.library.html) '../storefront_drawer_external_link_web.dart';
import '../storefront_navigation_editor_dialog.dart';
import '../storefront_theme_switcher.dart';
import 'animated_shopping_cart_icon.dart';
import 'collapsing_line_icon.dart';

typedef NavRevealTapCallback = void Function(Offset? globalOrigin);

enum TopNavDestination {
  home,
  wishlist,
  account,
  cart;

  static TopNavDestination? fromIndex(int? index) {
    if (index == null) return null;
    if (index < 0 || index >= TopNavDestination.values.length) return null;
    return TopNavDestination.values[index];
  }
}

class TopNavigationBar extends ConsumerWidget {
  final int? currentIndex;
  final ValueChanged<int>? onDestinationSelected;
  final NavRevealTapCallback? onMenuTap;
  final bool isMenuOpen;
  final Animation<double>? menuProgress;
  final bool hideChromeForOpenMenu;
  final NavRevealTapCallback? onSearchTap;
  final VoidCallback? onBrandTripleTap;
  final Color foregroundColor;
  final bool expandedMobile;
  final bool showOnlyThemeSwitcher;

  /// When true, the trailing wishlist / account / cart icons are hidden.
  /// Used by the Nike storefront theme where those destinations live in
  /// the floating bottom nav instead. Dior keeps them visible.
  final bool hideTrailingDestinations;

  /// Forwarded to [StorefrontThemeSwitcher.visualPosition] so the selected pill
  /// can follow an interactive theme swipe (0 = Sport, 1 = Luxe).
  final Animation<double>? themeSwitcherVisualPosition;
  final StorefrontThemeSelectionCallback? onThemeSelected;

  /// Forces the centered theme-switcher slot (replacing the centered brand
  /// logo) regardless of the brand setting. Used on the mobile landing page so
  /// the swipe switcher keeps the same coordinates across Sport and Luxe.
  final bool forceCenteredThemeSwitcher;

  const TopNavigationBar({
    super.key,
    this.currentIndex,
    this.onDestinationSelected,
    this.onMenuTap,
    this.isMenuOpen = false,
    this.menuProgress,
    this.hideChromeForOpenMenu = false,
    this.onSearchTap,
    this.onBrandTripleTap,
    this.foregroundColor = const Color(0xFF2B2B2B),
    this.expandedMobile = true,
    this.showOnlyThemeSwitcher = false,
    this.hideTrailingDestinations = false,
    this.themeSwitcherVisualPosition,
    this.onThemeSelected,
    this.forceCenteredThemeSwitcher = false,
  });

  void _select(BuildContext context, TopNavDestination destination) {
    final cb = onDestinationSelected;
    if (cb != null) {
      cb(destination.index);
      return;
    }
    final locale = Localizations.localeOf(context).languageCode;
    switch (destination) {
      case TopNavDestination.home:
        context.go(
          CatalogRoutes.localizedLocation(CatalogRoutes.home, locale: locale),
        );
        break;
      case TopNavDestination.wishlist:
        break;
      case TopNavDestination.account:
        showCustomerAccountModal(context);
        break;
      case TopNavDestination.cart:
        context.push(CatalogRoutes.cart);
        break;
    }
  }

  void _openBrandLink(BuildContext context, String href) {
    final target = StorefrontBrandSettings.normalizedHref(href);
    if (target.startsWith('http://') || target.startsWith('https://')) {
      openStorefrontDrawerExternalLink(target);
      return;
    }
    context.go(
      CatalogRoutes.localizedLocation(
        target,
        locale: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final cartItemCount = ref.watch(cartItemCountProvider);
    final brandSettings = ref.watch(
      storefrontBrandSettingsProvider.select(
        (async) => async.value ?? StorefrontBrandSettings.fallback,
      ),
    );
    // Navigation settings only ever reads the resolved value here, so select
    // it to skip rebuilds on pure loading/refresh transitions.
    final navigationSettings = ref.watch(
      storefrontNavigationSettingsProvider.select(
        (async) => async.value ?? StorefrontNavigationSettings.fallback,
      ),
    );
    final isEditMode = ref.watch(editModeProvider);
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isMobile = !isTablet && !isDesktop;
    final useExpandedMobile = isMobile && expandedMobile;
    final iconSize = isMobile
        ? (expandedMobile ? 22.0 : 18.0)
        : (isDesktop ? 20.0 : 19.0);
    final logoSize = isDesktop
        ? 28.0
        : (isTablet ? 26.0 : (expandedMobile ? 30.0 : 20.0));
    final logoMaxWidth = isDesktop ? 320.0 : (isTablet ? 260.0 : 200.0);
    final verticalPadding = isDesktop
        ? 14.0
        : (isTablet ? 12.0 : (expandedMobile ? 18.0 : 8.0));
    final horizontalPadding = isDesktop
        ? 24.0
        : (useExpandedMobile ? 6.0 : 14.0);
    final iconButtonWidth = useExpandedMobile ? 38.0 : 48.0;
    final renderedIconSlotWidth = 40.0;
    final iconButtonConstraints = useExpandedMobile
        ? const BoxConstraints.tightFor(width: 38, height: 38)
        : const BoxConstraints.tightFor(width: 48, height: 48);
    final iconButtonPadding = useExpandedMobile ? EdgeInsets.zero : null;
    final searchIcon = useExpandedMobile ? CupertinoIcons.search : Icons.search;
    final favoriteIcon = useExpandedMobile
        ? CupertinoIcons.heart
        : Icons.favorite_border;
    final favoriteIconActive = useExpandedMobile
        ? CupertinoIcons.heart_fill
        : Icons.favorite;
    final accountIcon = useExpandedMobile
        ? CupertinoIcons.person
        : Icons.person_outline;
    final accountIconActive = useExpandedMobile
        ? CupertinoIcons.person_fill
        : Icons.person;
    final bagIcon = useExpandedMobile
        ? CupertinoIcons.bag
        : Icons.shopping_bag_outlined;
    final bagIconActive = useExpandedMobile
        ? CupertinoIcons.bag_fill
        : Icons.shopping_bag;
    final brandLogoTextStyle = GoogleFonts.cormorantGaramond(
      fontSize: logoSize,
      fontWeight: FontWeight.w500,
      color: foregroundColor,
      letterSpacing: 0,
      height: 1,
    );
    final sidePadding = StorefrontLayout.outerPaddingFor(
      width,
      maxWidth: 1440,
      minHorizontalPadding: horizontalPadding,
    );
    final contentWidth = width - (sidePadding * 2);
    final logoTextWidth = estimateStorefrontLogoTextWidth(
      context: context,
      title: brandSettings.title,
      style: brandLogoTextStyle,
      maxWidth: logoMaxWidth,
    );
    final themeSwitcherLeadingGap = storefrontThemeSwitcherNavLeadingGap(
      contentWidth: contentWidth,
      leadingControlsWidth: iconButtonWidth * (isMobile ? 2 : 1),
      logoTextWidth: logoTextWidth,
    );
    final logoSlotThemeSwitcherWidth =
        storefrontThemeSwitcherWidthForBrandTitle(
          context: context,
          brandTitle: brandSettings.title,
          isCompact: false,
          minWidth: storefrontThemeSwitcherLogoSlotWidth,
          maxWidth: logoMaxWidth,
        );

    final activeDestination = TopNavDestination.fromIndex(currentIndex);
    final effectiveMenuProgress =
        menuProgress ?? AlwaysStoppedAnimation<double>(isMenuOpen ? 1 : 0);
    final chromeOpacity = Tween<double>(
      begin: 1,
      end: hideChromeForOpenMenu ? 0 : 1,
    ).animate(effectiveMenuProgress);

    Widget destinationIcon(
      TopNavDestination destination, {
      required IconData inactive,
      required IconData active,
      required String semanticLabel,
      int badgeCount = 0,
      bool usesAnimatedCartIcon = false,
    }) {
      final isActive = activeDestination == destination;
      return _NavIcon(
        icon: isActive ? active : inactive,
        iconSize: iconSize,
        foregroundColor: foregroundColor,
        useExpandedMobile: useExpandedMobile,
        constraints: iconButtonConstraints,
        padding: iconButtonPadding,
        semanticLabel: semanticLabel,
        badgeCount: badgeCount,
        usesAnimatedCartIcon: usesAnimatedCartIcon,
        onPressed: (_) => _select(context, destination),
      );
    }

    final searchButton = _NavIcon(
      icon: searchIcon,
      iconSize: iconSize,
      foregroundColor: foregroundColor,
      useExpandedMobile: useExpandedMobile,
      constraints: iconButtonConstraints,
      padding: iconButtonPadding,
      semanticLabel: l10n.navSearchAction,
      badgeCount: 0,
      usesAnimatedCartIcon: false,
      onPressed: (origin) {
        final cb = onSearchTap;
        if (cb != null) {
          cb(origin);
        } else {
          context.go(
            CatalogRoutes.localizedLocation(
              CatalogRoutes.search,
              locale: Localizations.localeOf(context).languageCode,
            ),
          );
        }
      },
    );
    final replaceMobileLogoWithThemeSwitcher =
        isMobile &&
        !showOnlyThemeSwitcher &&
        !hideTrailingDestinations &&
        (brandSettings.replaceMobileLogoWithThemeSwitcher ||
            forceCenteredThemeSwitcher);
    final showLeadingThemeSwitcher =
        !showOnlyThemeSwitcher &&
        !hideTrailingDestinations &&
        !replaceMobileLogoWithThemeSwitcher;
    final showCenteredThemeSwitcher =
        showOnlyThemeSwitcher || replaceMobileLogoWithThemeSwitcher;
    Widget themeSwitcher({bool logoSlot = false}) {
      return StorefrontThemeSwitcher(
        foregroundColor: foregroundColor,
        isCompact: isMobile && !logoSlot,
        diorLabel: logoSlot ? brandSettings.title : null,
        width: isMobile
            ? (logoSlot
                  ? logoSlotThemeSwitcherWidth
                  : storefrontThemeSwitcherCompactNavWidth)
            : null,
        onThemeSelected: onThemeSelected,
        visualPosition: themeSwitcherVisualPosition,
      );
    }

    Widget settingsMenuButton() {
      return SizedBox(
        width: 34,
        height: 34,
        child: PopupMenuButton<_StorefrontSettingsAction>(
          tooltip: 'Réglages storefront',
          splashRadius: 18,
          padding: EdgeInsets.zero,
          icon: Icon(Icons.tune, size: 17, color: foregroundColor),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _StorefrontSettingsAction.brandIdentity,
              child: Text('Identité de la boutique'),
            ),
            PopupMenuItem(
              value: _StorefrontSettingsAction.mobileNavigation,
              child: Text('Navigation mobile'),
            ),
          ],
          onSelected: (action) {
            switch (action) {
              case _StorefrontSettingsAction.brandIdentity:
                StorefrontBrandEditorDialog.show(
                  context,
                  initialSettings: brandSettings,
                );
                break;
              case _StorefrontSettingsAction.mobileNavigation:
                StorefrontNavigationEditorDialog.show(
                  context,
                  initialSettings: navigationSettings,
                );
                break;
            }
          },
        ),
      );
    }

    Widget centeredThemeSwitcher() {
      if (!isEditMode) return themeSwitcher(logoSlot: true);
      const settingsButtonSize = 34.0;
      const settingsGap = 4.0;
      return SizedBox(
        width:
            logoSlotThemeSwitcherWidth +
            ((settingsButtonSize + settingsGap) * 2),
        height: settingsButtonSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            themeSwitcher(logoSlot: true),
            Positioned(right: 0, child: settingsMenuButton()),
          ],
        ),
      );
    }

    Widget hideWhenThemeSwitcherOnly(Widget child, {Size size = Size.zero}) {
      if (!showOnlyThemeSwitcher) return child;
      return SizedBox.fromSize(size: size);
    }

    return StorefrontPageSection(
      maxWidth: 1440,
      minHorizontalPadding: horizontalPadding,
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              hideWhenThemeSwitcherOnly(
                _DiorMenuButton(
                  iconSize: iconSize,
                  foregroundColor: foregroundColor,
                  useExpandedMobile: useExpandedMobile,
                  constraints: iconButtonConstraints,
                  padding: iconButtonPadding,
                  progress: effectiveMenuProgress,
                  isOpen: isMenuOpen,
                  onPressed: onMenuTap,
                ),
                size: Size.square(renderedIconSlotWidth),
              ),
              if (isMobile)
                _NavbarChromeFade(
                  opacity: chromeOpacity,
                  child: hideWhenThemeSwitcherOnly(
                    searchButton,
                    size: Size.square(renderedIconSlotWidth),
                  ),
                ),
              if (showLeadingThemeSwitcher)
                _NavbarChromeFade(
                  opacity: chromeOpacity,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isMobile ? themeSwitcherLeadingGap : 8,
                    ),
                    child: themeSwitcher(),
                  ),
                ),
              const Spacer(),
              _NavbarChromeFade(
                opacity: chromeOpacity,
                child: hideWhenThemeSwitcherOnly(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDesktop || isTablet) searchButton,
                      if (!hideTrailingDestinations) ...[
                        destinationIcon(
                          TopNavDestination.wishlist,
                          inactive: favoriteIcon,
                          active: favoriteIconActive,
                          semanticLabel: l10n.navWishlist,
                        ),
                        destinationIcon(
                          TopNavDestination.account,
                          inactive: accountIcon,
                          active: accountIconActive,
                          semanticLabel: l10n.navAccount,
                        ),
                        destinationIcon(
                          TopNavDestination.cart,
                          inactive: bagIcon,
                          active: bagIconActive,
                          semanticLabel: l10n.navCart,
                          badgeCount: cartItemCount,
                          usesAnimatedCartIcon: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          _NavbarChromeFade(
            opacity: chromeOpacity,
            child: Center(
              child: showCenteredThemeSwitcher
                  ? centeredThemeSwitcher()
                  : Semantics(
                      button: true,
                      label: l10n.navBackHome,
                      child: _BrandLogoTapTarget(
                        onTap: () =>
                            _openBrandLink(context, brandSettings.href),
                        onTripleTap: onBrandTripleTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: logoMaxWidth,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    brandSettings.title,
                                    style: brandLogoTextStyle,
                                  ),
                                ),
                              ),
                              if (isEditMode) ...[
                                const SizedBox(width: 4),
                                settingsMenuButton(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Offset? _globalCenterOf(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) {
    return null;
  }
  return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
}

enum _StorefrontSettingsAction { brandIdentity, mobileNavigation }

class _BrandLogoTapTarget extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onTripleTap;
  final BorderRadius borderRadius;
  final Widget child;

  const _BrandLogoTapTarget({
    required this.onTap,
    required this.borderRadius,
    required this.child,
    this.onTripleTap,
  });

  @override
  State<_BrandLogoTapTarget> createState() => _BrandLogoTapTargetState();
}

class _BrandLogoTapTargetState extends State<_BrandLogoTapTarget> {
  static const _tripleTapWindow = Duration(milliseconds: 650);

  Timer? _tapTimer;
  int _tapCount = 0;

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final onTripleTap = widget.onTripleTap;
    if (onTripleTap == null) {
      widget.onTap();
      return;
    }

    _tapCount += 1;
    _tapTimer?.cancel();

    if (_tapCount >= 3) {
      _tapCount = 0;
      onTripleTap();
      return;
    }

    _tapTimer = Timer(_tripleTapWindow, () {
      if (!mounted) return;
      final wasSingleTap = _tapCount == 1;
      _tapCount = 0;
      if (wasSingleTap) {
        widget.onTap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: widget.borderRadius,
      child: widget.child,
    );
  }
}

class _NavbarChromeFade extends StatelessWidget {
  final Animation<double> opacity;
  final Widget child;

  const _NavbarChromeFade({required this.opacity, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: opacity,
      builder: (context, child) {
        final value = opacity.value.clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: value < 0.05,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

class _DiorMenuButton extends StatelessWidget {
  final double iconSize;
  final Color foregroundColor;
  final bool useExpandedMobile;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final Animation<double> progress;
  final bool isOpen;
  final NavRevealTapCallback? onPressed;

  const _DiorMenuButton({
    required this.iconSize,
    required this.foregroundColor,
    required this.useExpandedMobile,
    required this.constraints,
    required this.padding,
    required this.progress,
    required this.isOpen,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        final cb = onPressed;
        return IconButton(
          splashRadius: 20,
          tooltip: isOpen
              ? context.l10n.navCloseMenu
              : context.l10n.navOpenMenu,
          visualDensity: VisualDensity.compact,
          constraints: constraints,
          padding: padding,
          onPressed: cb == null
              ? null
              : () {
                  cb(_globalCenterOf(buttonContext));
                },
          icon: DiorCollapsingLineIcon(
            progress: progress,
            shape: DiorCollapsingLineIconShape.menuToClose,
            color: foregroundColor,
            size: iconSize,
            useExpandedMobile: useExpandedMobile,
          ),
        );
      },
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Color foregroundColor;
  final bool useExpandedMobile;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;
  final int badgeCount;
  final bool usesAnimatedCartIcon;
  final NavRevealTapCallback onPressed;

  const _NavIcon({
    required this.icon,
    required this.iconSize,
    required this.foregroundColor,
    required this.useExpandedMobile,
    required this.constraints,
    required this.padding,
    required this.semanticLabel,
    required this.badgeCount,
    required this.usesAnimatedCartIcon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final badgeLabel = badgeCount > 0 ? badgeCount.toString() : null;
    final resolvedSemanticLabel = badgeCount > 0
        ? context.l10n.navCartItemsCount(badgeCount)
        : semanticLabel;
    final badgeDiameter = useExpandedMobile ? 17.0 : 15.0;
    final badgeFontSize = useExpandedMobile ? 11.5 : 10.0;
    final badgeBackground =
        ThemeData.estimateBrightnessForColor(foregroundColor) == Brightness.dark
        ? Colors.white
        : const Color(0xFF2B2B2B);
    final badgeForeground =
        ThemeData.estimateBrightnessForColor(badgeBackground) == Brightness.dark
        ? Colors.white
        : foregroundColor;
    final iconUnit = usesAnimatedCartIcon
        ? AnimatedShoppingCartIcon(
            color: foregroundColor,
            size: iconSize,
            brightness: Brightness.light,
            badgeCount: badgeCount,
            badgeColor: badgeBackground,
            badgeTextColor: badgeForeground,
            badgePosition: AnimatedShoppingCartBadgePosition.bottomRight,
          )
        : Icon(
            icon,
            size: iconSize,
            color: foregroundColor,
            weight: useExpandedMobile ? 300 : null,
          );

    return Builder(
      builder: (buttonContext) {
        return IconButton(
          splashRadius: 20,
          tooltip: resolvedSemanticLabel,
          visualDensity: VisualDensity.compact,
          constraints: constraints,
          padding: padding,
          onPressed: () {
            onPressed(_globalCenterOf(buttonContext));
          },
          icon: usesAnimatedCartIcon
              ? iconUnit
              : Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    iconUnit,
                    if (badgeLabel != null)
                      Positioned(
                        right: useExpandedMobile ? -4 : -5,
                        bottom: useExpandedMobile ? -4 : -3,
                        child: Container(
                          width: badgeDiameter,
                          height: badgeDiameter,
                          decoration: BoxDecoration(
                            color: badgeBackground,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            key: kSharedNavCartCountBadgeKey,
                            badgeLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: badgeForeground,
                              fontSize: badgeFontSize,
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
