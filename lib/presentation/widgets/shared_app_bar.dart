import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../l10n/l10n_extension.dart';
import 'navigation/top_navigation_bar.dart';
import 'storefront_layout.dart';

class SharedPdpNavBar extends StatelessWidget {
  final Color foregroundColor;
  final bool expandedMobile;

  const SharedPdpNavBar({
    super.key,
    this.foregroundColor = const Color(0xFF2B2B2B),
    this.expandedMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    return TopNavigationBar(
      foregroundColor: foregroundColor,
      expandedMobile: expandedMobile,
    );
  }
}

class SharedNavBar extends StatelessWidget {
  const SharedNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedPdpNavBar();
  }
}

class SharedSearchBar extends StatefulWidget {
  final String? initialQuery;

  const SharedSearchBar({super.key, this.initialQuery});

  @override
  State<SharedSearchBar> createState() => _SharedSearchBarState();
}

class _SharedSearchBarState extends State<SharedSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    context.go(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.searchUrl(query: trimmed),
        locale: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isDesktop = StorefrontLayout.isDesktop(width);

    return StorefrontPageSection(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 12 : (isTablet ? 10 : 8),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : (isTablet ? 18 : 16),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F4),
          border: Border.all(color: const Color(0xFFE6E3DD)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: context.l10n.navSearchHint,
                  hintStyle: TextStyle(
                    color: const Color(0xFF7B7F82),
                    fontSize: isDesktop ? 15 : (isTablet ? 14.5 : 14),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isDesktop ? 14 : (isTablet ? 13 : 12),
                  ),
                ),
                style: TextStyle(
                  color: const Color(0xFF2F2F2C),
                  fontSize: isDesktop ? 15 : (isTablet ? 14.5 : 14),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _controller.clear(),
                  child: Icon(
                    Icons.close,
                    color: const Color(0xFF7B7F82),
                    size: 20,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SharedBreadcrumbItem {
  final String label;
  final String? routeName;

  const SharedBreadcrumbItem({required this.label, this.routeName});

  bool get isClickable => routeName != null && routeName!.trim().isNotEmpty;
}

class SharedBreadcrumb extends StatelessWidget {
  final List<SharedBreadcrumbItem> items;
  final double maxWidth;

  const SharedBreadcrumb({
    super.key,
    required this.items,
    this.maxWidth = StorefrontLayout.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isDesktop = StorefrontLayout.isDesktop(width);

    return StorefrontPageSection(
      maxWidth: maxWidth,
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 14 : (isTablet ? 12 : 8),
      ),
      child: _BreadcrumbTrail(
        items: items,
        fontSize: isDesktop ? 14 : (isTablet ? 13.5 : 13),
        scrollable: false,
        underlineLinks: true,
      ),
    );
  }
}

class SharedInlineBreadcrumb extends StatelessWidget {
  final List<SharedBreadcrumbItem> items;
  final double fontSize;
  final bool scrollable;
  final bool underlineLinks;
  final Color? linkColor;
  final Color? currentColor;
  final Color? separatorColor;

  const SharedInlineBreadcrumb({
    super.key,
    required this.items,
    this.fontSize = 13,
    this.scrollable = true,
    this.underlineLinks = true,
    this.linkColor,
    this.currentColor,
    this.separatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return _BreadcrumbTrail(
      items: items,
      fontSize: fontSize,
      scrollable: scrollable,
      underlineLinks: underlineLinks,
      linkColor: linkColor,
      currentColor: currentColor,
      separatorColor: separatorColor,
    );
  }
}

class _BreadcrumbTrail extends StatelessWidget {
  final List<SharedBreadcrumbItem> items;
  final double fontSize;
  final bool scrollable;
  final bool underlineLinks;
  final Color? linkColor;
  final Color? currentColor;
  final Color? separatorColor;

  const _BreadcrumbTrail({
    required this.items,
    required this.fontSize,
    required this.scrollable,
    required this.underlineLinks,
    this.linkColor,
    this.currentColor,
    this.separatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final row = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _BreadcrumbLink(
            item: items[i],
            isLast: i == items.length - 1,
            fontSize: fontSize,
            underlineLinks: underlineLinks,
            linkColor: linkColor,
            currentColor: currentColor,
          ),
          if (i < items.length - 1)
            Text(
              '  /  ',
              style: TextStyle(
                fontSize: fontSize,
                color: separatorColor ?? Colors.grey,
              ),
            ),
        ],
      ],
    );

    if (!scrollable) {
      return row;
    }

    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
  }
}

class _BreadcrumbLink extends StatelessWidget {
  final SharedBreadcrumbItem item;
  final bool isLast;
  final double fontSize;
  final bool underlineLinks;
  final Color? linkColor;
  final Color? currentColor;

  const _BreadcrumbLink({
    required this.item,
    required this.isLast,
    required this.fontSize,
    required this.underlineLinks,
    this.linkColor,
    this.currentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLast
        ? (currentColor ?? const Color(0xFF7B7F82))
        : (linkColor ?? const Color(0xFF2F2F2C));
    final textStyle = TextStyle(
      fontSize: fontSize,
      color: color,
      decoration: item.isClickable && underlineLinks
          ? TextDecoration.underline
          : null,
      fontWeight: item.isClickable ? FontWeight.w500 : FontWeight.w400,
    );

    if (!item.isClickable) {
      return Text(item.label, style: textStyle);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.go(
          CatalogRoutes.localizedLocation(
            item.routeName!,
            locale: Localizations.localeOf(context).languageCode,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(item.label, style: textStyle),
        ),
      ),
    );
  }
}
