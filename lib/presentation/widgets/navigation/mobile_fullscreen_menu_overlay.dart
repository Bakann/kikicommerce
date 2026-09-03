import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import '../../../core/constants.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers/search_providers.dart';
import '../storefront_category_drawer.dart';

enum MobileFullscreenMenuMode { navigation, search }

class MobileFullscreenMenuOverlay extends StatefulWidget {
  static const overlayKey = ValueKey('mobile-fullscreen-menu-overlay');
  static const panelKey = ValueKey('mobile-fullscreen-menu-panel');
  static const contentKey = ValueKey('mobile-fullscreen-menu-content');
  static const searchFieldKey = ValueKey('mobile-fullscreen-menu-search-field');

  final Animation<double> progress;
  final bool isOpen;
  final double topInset;
  final VoidCallback onClose;
  final VoidCallback? onSearchClose;
  final MobileFullscreenMenuMode mode;
  final Offset? revealOriginGlobal;

  const MobileFullscreenMenuOverlay({
    super.key,
    required this.progress,
    required this.isOpen,
    required this.topInset,
    required this.onClose,
    this.onSearchClose,
    this.mode = MobileFullscreenMenuMode.navigation,
    this.revealOriginGlobal,
  });

  @override
  State<MobileFullscreenMenuOverlay> createState() =>
      _MobileFullscreenMenuOverlayState();
}

class _MobileFullscreenMenuOverlayState
    extends State<MobileFullscreenMenuOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Mobile menu overlay');
  final GlobalKey _overlayCoordinateKey = GlobalKey(
    debugLabel: 'Mobile menu overlay coordinates',
  );

  @override
  void didUpdateWidget(covariant MobileFullscreenMenuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.mode == MobileFullscreenMenuMode.navigation) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _closeActiveMode() {
    if (widget.mode == MobileFullscreenMenuMode.search) {
      (widget.onSearchClose ?? widget.onClose).call();
      return;
    }
    widget.onClose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.isOpen) {
      _closeActiveMode();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final reveal = CurvedAnimation(
      parent: widget.progress,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final items = CurvedAnimation(
      parent: widget.progress,
      curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0, 0.7, curve: Curves.easeInCubic),
    );

    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, child) {
        final progressValue = widget.progress.value;
        final isActive = disableAnimations
            ? widget.isOpen
            : widget.isOpen || progressValue > 0;
        return IgnorePointer(ignoring: !isActive, child: child);
      },
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: RepaintBoundary(
          child: SizedBox.expand(
            key: _overlayCoordinateKey,
            child: AnimatedBuilder(
              animation: widget.progress,
              builder: (context, _) {
                final progressValue = widget.progress.value;
                final isActive = disableAnimations
                    ? widget.isOpen
                    : widget.isOpen || progressValue > 0;
                final revealValue =
                    (disableAnimations
                            ? (widget.isOpen ? 1.0 : 0.0)
                            : reveal.value)
                        .clamp(0.0, 1.0);
                final itemsValue =
                    (disableAnimations
                            ? (widget.isOpen ? 1.0 : 0.0)
                            : items.value)
                        .clamp(0.0, 1.0);
                final effectiveItems = disableAnimations
                    ? AlwaysStoppedAnimation<double>(itemsValue)
                    : items;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final safeTop = MediaQuery.paddingOf(context).top;
                    final origin = _resolveRevealOrigin(
                      constraints: constraints,
                      safeTop: safeTop,
                    );
                    final dx = math.max(
                      origin.dx,
                      constraints.maxWidth - origin.dx,
                    );
                    final dy = math.max(
                      origin.dy,
                      constraints.maxHeight - origin.dy,
                    );
                    final maxRadius = math.sqrt(dx * dx + dy * dy);
                    final radius = isActive ? maxRadius * revealValue : 0.0;
                    final panelHeight = isActive ? constraints.maxHeight : 0.0;

                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        if (isActive)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: const SizedBox.expand(),
                            ),
                          ),
                        SizedBox(
                          key: MobileFullscreenMenuOverlay.panelKey,
                          width: constraints.maxWidth,
                          height: panelHeight,
                          child: ClipPath(
                            clipper: _CircularRevealClipper(
                              center: origin,
                              radius: radius,
                            ),
                            child: SizedBox.expand(
                              child: _MenuOverlayContent(
                                mode: widget.mode,
                                topInset: widget.topInset,
                                isOpen: widget.isOpen,
                                onClose: widget.onClose,
                                onSearchClose: _closeActiveMode,
                                items: effectiveItems,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Offset _resolveRevealOrigin({
    required BoxConstraints constraints,
    required double safeTop,
  }) {
    final globalOrigin = widget.revealOriginGlobal;
    final renderObject = _overlayCoordinateKey.currentContext
        ?.findRenderObject();

    if (globalOrigin != null && renderObject is RenderBox) {
      return renderObject.globalToLocal(globalOrigin);
    }

    return _fallbackOrigin(constraints, safeTop);
  }

  Offset _fallbackOrigin(BoxConstraints constraints, double safeTop) {
    switch (widget.mode) {
      case MobileFullscreenMenuMode.navigation:
        return Offset(32, safeTop + 36);
      case MobileFullscreenMenuMode.search:
        // Last-resort fallback; the normal path uses the tapped search icon.
        return Offset(constraints.maxWidth - 32, safeTop + 36);
    }
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  const _CircularRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) =>
      center != oldClipper.center || radius != oldClipper.radius;
}

class _MenuOverlayContent extends StatelessWidget {
  final MobileFullscreenMenuMode mode;
  final double topInset;
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onSearchClose;
  final Animation<double> items;

  const _MenuOverlayContent({
    required this.mode,
    required this.topInset,
    required this.isOpen,
    required this.onClose,
    required this.onSearchClose,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: MobileFullscreenMenuOverlay.overlayKey,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.only(
          top: mode == MobileFullscreenMenuMode.navigation ? topInset : 0,
        ),
        child: FadeTransition(
          opacity: items,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.025),
              end: Offset.zero,
            ).animate(items),
            child: mode == MobileFullscreenMenuMode.search
                ? _PremiumSearchPanel(
                    isActive: isOpen && mode == MobileFullscreenMenuMode.search,
                    onClose: onSearchClose,
                  )
                : StorefrontNavigationMenuContent(
                    key: MobileFullscreenMenuOverlay.contentKey,
                    variant: StorefrontNavigationMenuVariant.fullscreen,
                    showCloseHeader: false,
                    showFooter: true,
                    isOpen: isOpen,
                    onClose: onClose,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSearchPanel extends ConsumerStatefulWidget {
  final bool isActive;
  final VoidCallback onClose;

  const _PremiumSearchPanel({required this.isActive, required this.onClose});

  @override
  ConsumerState<_PremiumSearchPanel> createState() =>
      _PremiumSearchPanelState();
}

class _PremiumSearchPanelState extends ConsumerState<_PremiumSearchPanel> {
  // Wait for a typing pause before querying so we don't fire per keystroke.
  static const _debounce = Duration(milliseconds: 250);

  late final TextEditingController _controller;
  late final FocusNode _searchFocusNode;
  Timer? _debounceTimer;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _searchFocusNode = FocusNode(debugLabel: 'Premium search field');
    _requestSearchFocus();
  }

  @override
  void didUpdateWidget(covariant _PremiumSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _requestSearchFocus();
    }
  }

  void _requestSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
    });
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    widget.onClose();
    context.go(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.searchUrl(query: trimmed),
        locale: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 600 ? 96.0 : 40.0;

    // Real product-name suggestions, shared with the /search entry page.
    final suggestions = _debouncedQuery.length < 2
        ? const <String>[]
        : (ref.watch(productNameSuggestionsProvider(_debouncedQuery)).value ??
              const <String>[]);

    return Material(
      color: Colors.white,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding + 126,
              horizontalPadding,
              40,
            ),
            children: [
              _SearchInput(
                controller: _controller,
                focusNode: _searchFocusNode,
                onSubmit: _submit,
                onChanged: () => _onChanged(_controller.text),
              ),
              const SizedBox(height: 72),
              if (suggestions.isNotEmpty)
                _SearchSuggestionSection(
                  title: context.l10n.searchSuggestionsTitle,
                  icon: Icons.search,
                  items: suggestions,
                  emphasizedTerm: _debouncedQuery,
                  onSelected: _submit,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onChanged;

  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Lancer la recherche',
          onPressed: () => onSubmit(controller.text),
          icon: const Icon(Icons.search, size: 31, color: kDrawerChrome),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: MobileFullscreenMenuOverlay.searchFieldKey,
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            onChanged: (_) => onChanged(),
            cursorColor: kDrawerChrome,
            decoration: const InputDecoration(
              hintText: 'Search',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintStyle: TextStyle(
                fontFamily: kDrawerFontFamily,
                color: Color(0xFF70727A),
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
            style: const TextStyle(
              fontFamily: kDrawerFontFamily,
              color: kDrawerChrome,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.12,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox(width: 44);
            return IconButton(
              tooltip: 'Effacer la recherche',
              onPressed: () {
                controller.clear();
                onChanged();
                focusNode.requestFocus();
              },
              icon: const Icon(
                Icons.cancel,
                size: 22,
                color: Color(0xFF777982),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SearchSuggestionSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String? emphasizedTerm;
  final ValueChanged<String> onSelected;

  const _SearchSuggestionSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.onSelected,
    this.emphasizedTerm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: kDrawerFontFamily,
            color: Color(0xFF70727A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in items)
          InkWell(
            onTap: () => onSelected(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(icon, size: 21, color: const Color(0xFF70727A)),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _HighlightedSuggestionText(
                      text: item,
                      emphasizedTerm: emphasizedTerm,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HighlightedSuggestionText extends StatelessWidget {
  final String text;
  final String? emphasizedTerm;

  const _HighlightedSuggestionText({
    required this.text,
    required this.emphasizedTerm,
  });

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontFamily: kDrawerFontFamily,
      color: Color(0xFF70727A),
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    const emphasizedStyle = TextStyle(
      fontFamily: kDrawerFontFamily,
      color: kDrawerChrome,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      height: 1.3,
    );

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: _spansFor(text, emphasizedTerm, emphasizedStyle),
      ),
    );
  }

  List<InlineSpan> _spansFor(
    String text,
    String? term,
    TextStyle emphasizedStyle,
  ) {
    final normalizedTerm = term?.trim();
    if (normalizedTerm == null || normalizedTerm.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowerText = text.toLowerCase();
    final lowerTerm = normalizedTerm.toLowerCase();
    final spans = <InlineSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      final match = lowerText.indexOf(lowerTerm, cursor);
      if (match < 0) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }
      if (match > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match)));
      }
      final end = match + normalizedTerm.length;
      spans.add(
        TextSpan(text: text.substring(match, end), style: emphasizedStyle),
      );
      cursor = end;
    }
    return spans;
  }
}
