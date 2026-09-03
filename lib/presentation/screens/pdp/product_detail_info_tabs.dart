import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../domain/catalog/catalog_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../../widgets/animations/text_reveal/text_reveal.dart';
import '../product_detail_layout_spec.dart';

class ProductDetailInfoTabs extends StatefulWidget {
  final CatalogProduct product;
  final ProductDetailLayoutSpec layout;
  final String visibleSummary;
  final bool isEditMode;

  const ProductDetailInfoTabs({
    super.key,
    required this.product,
    required this.layout,
    required this.visibleSummary,
    required this.isEditMode,
  });

  @override
  State<ProductDetailInfoTabs> createState() => _ProductDetailInfoTabsState();
}

class _ProductDetailInfoTabsState extends State<ProductDetailInfoTabs> {
  static const int _mobileDescriptionSnippetLength = 620;
  static const int _wideDescriptionSnippetLength = 520;

  int _selectedInfoIndex = 0;
  bool _descriptionExpanded = false;

  Key get _descriptionRevealKey {
    final slug = widget.product.slug?.trim();
    final slugOrCode = slug != null && slug.isNotEmpty
        ? slug
        : widget.product.code.trim();
    return ValueKey('pdp-description-text-${widget.product.id}-$slugOrCode');
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.pdpTabSizeAndFit,
      context.l10n.pdpTabShippingAndReturns,
    ];
    final desktopLabels = [
      context.l10n.pdpTabSizeAndFitInfo,
      context.l10n.pdpTabShippingAndReturnsLong,
    ];

    if (widget.layout.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDescriptionBlock(),
          const SizedBox(height: 46),
          _MobileProductDetailAccordions(
            entries: [
              _MobileProductDetailAccordionEntry(
                title: context.l10n.pdpTabSizeAndFitInfo,
                body: _buildSizingBody(),
              ),
              _MobileProductDetailAccordionEntry(
                title: context.l10n.pdpTabShippingAndReturnsLong,
                body: _buildShippingBody(),
              ),
            ],
          ),
        ],
      );
    }

    final labelStyle = TextStyle(
      fontSize: widget.layout.isMobile
          ? 12
          : (widget.layout.isDesktop ? 14 : 13),
      color: productDetailMutedTextColor,
      fontWeight: FontWeight.w400,
    );
    final activeStyle = labelStyle.copyWith(
      color: const Color(0xFF2A2A28),
      fontWeight: FontWeight.w500,
    );

    final activeLabels = widget.layout.isDesktop ? desktopLabels : labels;
    final selectedIndex = _selectedInfoIndex.clamp(0, activeLabels.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDescriptionBlock(),
        SizedBox(height: widget.layout.isDesktop ? 44 : 36),
        if (widget.layout.isDesktop)
          Row(
            children: [
              for (var index = 0; index < activeLabels.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedInfoIndex = index),
                    child: Align(
                      alignment: switch (index) {
                        0 => Alignment.centerLeft,
                        _ => Alignment.centerRight,
                      },
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: index == selectedIndex
                                  ? const Color(0xFF2A2A28)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Text(
                          activeLabels[index],
                          style: index == selectedIndex
                              ? activeStyle
                              : labelStyle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < activeLabels.length; index++) ...[
                  InkWell(
                    onTap: () => setState(() => _selectedInfoIndex = index),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index == activeLabels.length - 1
                            ? 0
                            : (widget.layout.isMobile ? 18 : 24),
                      ),
                      padding: EdgeInsets.only(
                        bottom: widget.layout.isMobile ? 10 : 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: index == selectedIndex
                                ? const Color(0xFF2A2A28)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        activeLabels[index],
                        style: index == selectedIndex
                            ? activeStyle
                            : labelStyle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        Container(height: 1, color: productDetailDividerColor),
        SizedBox(height: widget.layout.isDesktop ? 32 : 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: _buildInfoTabBody(selectedIndex),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTabBody(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return _buildSizingBody();
      case 1:
        return _buildShippingBody();
    }
    return const SizedBox.shrink();
  }

  Widget _buildDescriptionBlock() {
    final hasSummary = widget.visibleSummary.trim().isNotEmpty;
    final bodyText = hasSummary
        ? widget.visibleSummary
        : context.l10n.pdpDescriptionEmpty;
    final snippetLength = widget.layout.isMobile
        ? _mobileDescriptionSnippetLength
        : _wideDescriptionSnippetLength;
    final canExpand = bodyText.length > snippetLength;
    final displayText = !_descriptionExpanded && canExpand
        ? bodyText.substring(0, snippetLength)
        : bodyText;
    final descriptionStyle = widget.layout.isMobile
        ? GoogleFonts.cormorantGaramond(
            fontSize: 28,
            height: 1.14,
            letterSpacing: 0,
            color: const Color(0xFF33383B),
          )
        : GoogleFonts.notoSerif(
            fontSize: widget.layout.isDesktop ? 18 : 17,
            height: 1.58,
            letterSpacing: 0,
            color: const Color(0xFF454844),
          );

    if (widget.layout.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScrollLineRevealText(
            key: _descriptionRevealKey,
            text: displayText,
            style: descriptionStyle,
            textAlign: TextAlign.center,
            enabled: !widget.isEditMode,
            duration: const Duration(milliseconds: 700),
            wordStagger: const Duration(milliseconds: 45),
            lineStagger: const Duration(milliseconds: 110),
            wordTranslateY: -34,
            maxWordRotationDegrees: 6,
            viewportRevealFraction: 0.85,
            curve: Curves.easeOutBack,
          ),
          if (canExpand) ...[
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {
                  setState(() => _descriptionExpanded = !_descriptionExpanded);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF8A8F92),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    decoration: TextDecoration.underline,
                    height: 1.2,
                  ),
                ),
                child: Text(
                  _descriptionExpanded
                      ? context.l10n.pdpShowLess
                      : context.l10n.pdpShowMore,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ScrollLineRevealText(
              key: _descriptionRevealKey,
              text: displayText,
              style: descriptionStyle,
              textAlign: TextAlign.center,
              enabled: !widget.isEditMode,
              duration: const Duration(milliseconds: 700),
              wordStagger: const Duration(milliseconds: 45),
              lineStagger: const Duration(milliseconds: 110),
              wordTranslateY: -34,
              maxWordRotationDegrees: 6,
              viewportRevealFraction: 0.85,
              curve: Curves.easeOutBack,
            ),
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () {
                setState(() => _descriptionExpanded = !_descriptionExpanded);
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF7B7F82),
                textStyle: const TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  height: 1.2,
                ),
              ),
              child: Text(
                _descriptionExpanded
                    ? context.l10n.pdpShowLess
                    : context.l10n.pdpShowMore,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSizingBody() {
    final type = widget.product.productType?.trim();
    final brand = widget.product.brand?.trim();
    if (widget.layout.isMobile) {
      final parts = <String>[
        if (type != null && type.isNotEmpty)
          context.l10n.pdpSizingCategory(type),
        if (brand != null && brand.isNotEmpty)
          context.l10n.pdpSizingBrandUniverse(brand),
        context.l10n.pdpSizingDimensionsVary,
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final part in parts) _MobileProductBullet(part)],
      );
    }

    final parts = <String>[
      if (type != null && type.isNotEmpty)
        context.l10n.pdpSizingSilhouette(type.toLowerCase()),
      if (brand != null && brand.isNotEmpty)
        context.l10n.pdpSizingBrandUniverse(brand),
      context.l10n.pdpSizingSizeUpAdvice,
    ];

    return Text(
      parts.join(' '),
      style: TextStyle(
        fontSize: widget.layout.isDesktop ? 14.5 : 13.5,
        height: 1.6,
        color: const Color(0xFF646460),
      ),
    );
  }

  Widget _buildShippingBody() {
    if (widget.layout.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MobileProductBodyTitle(context.l10n.pdpShippingReturnsTitle),
          const SizedBox(height: 12),
          _MobileProductBodyText(context.l10n.pdpShippingReturnsBody),
          const SizedBox(height: 18),
          _MobileProductBodyText(context.l10n.pdpShippingFaqHint),
          const SizedBox(height: 22),
          _MobileProductBodyTitle(context.l10n.pdpShippingFreeTitle),
          const SizedBox(height: 12),
          _MobileProductBodyText(context.l10n.pdpShippingFreeBody),
          const SizedBox(height: 22),
          _MobileProductBodyTitle(context.l10n.pdpShippingDispatchTitle),
          const SizedBox(height: 12),
          _MobileProductBodyText(context.l10n.pdpShippingDispatchBody),
        ],
      );
    }

    return Text(
      context.l10n.pdpShippingSummary,
      style: const TextStyle(
        fontSize: 13.5,
        height: 1.6,
        color: Color(0xFF646460),
      ),
    );
  }
}

class _MobileProductDetailAccordionEntry {
  final String title;
  final Widget body;

  const _MobileProductDetailAccordionEntry({
    required this.title,
    required this.body,
  });
}

class _MobileProductDetailAccordions extends StatefulWidget {
  final List<_MobileProductDetailAccordionEntry> entries;

  const _MobileProductDetailAccordions({required this.entries});

  @override
  State<_MobileProductDetailAccordions> createState() =>
      _MobileProductDetailAccordionsState();
}

class _MobileProductDetailAccordionsState
    extends State<_MobileProductDetailAccordions> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(
          height: 1,
          thickness: 1,
          color: productDetailDividerColor,
        ),
        for (var index = 0; index < widget.entries.length; index++)
          _MobileProductAccordionTile(
            entry: widget.entries[index],
            isExpanded: _expandedIndex == index,
            onTap: () {
              setState(() {
                _expandedIndex = _expandedIndex == index ? null : index;
              });
            },
          ),
      ],
    );
  }
}

class _MobileProductAccordionTile extends StatelessWidget {
  final _MobileProductDetailAccordionEntry entry;
  final bool isExpanded;
  final VoidCallback onTap;

  const _MobileProductAccordionTile({
    required this.entry,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF303330),
                      height: 1.15,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF303330),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Align(alignment: Alignment.centerLeft, child: entry.body),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: productDetailDividerColor,
        ),
      ],
    );
  }
}

class _MobileProductBullet extends StatelessWidget {
  final String text;

  const _MobileProductBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text(
              '•',
              style: TextStyle(
                fontSize: 15,
                color: productDetailMutedTextColor,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _MobileProductBodyText(text)),
        ],
      ),
    );
  }
}

class _MobileProductBodyTitle extends StatelessWidget {
  final String text;

  const _MobileProductBodyTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF303330),
        height: 1.35,
      ),
    );
  }
}

class _MobileProductBodyText extends StatelessWidget {
  final String text;

  const _MobileProductBodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: productDetailMutedTextColor,
        height: 1.45,
      ),
    );
  }
}
