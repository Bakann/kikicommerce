import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../application/cms/cms_models.dart';
import '../../storefront_layout.dart';
import '../cms_href.dart';
import '../cms_text_reveal.dart';

class ServiceCardsSection extends StatelessWidget {
  final ServiceCardsConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const ServiceCardsSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    if (config.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isMobile = !isDesktop && !isTablet;
    final columns = isMobile ? 1 : (config.cards.length >= 3 ? 3 : 2);
    final spacing = isMobile ? 16.0 : 24.0;

    return Container(
      color: const Color(0xFFFAF8F4),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 48 : 80,
        horizontal: isMobile ? 16 : 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: CmsRevealGroup(
            key: textRevealId == null
                ? null
                : ValueKey('cms-service-cards-text-reveal-$textRevealId'),
            trigger: CmsRevealTrigger.viewport,
            enabled: enableTextReveal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (config.title != null)
                CmsRevealText(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      config.title!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: isMobile ? 26 : 34,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              CmsRevealText(
                child: _ServiceCardsGrid(
                  cards: config.cards,
                  columns: columns,
                  spacing: spacing,
                  aspectRatio: isMobile ? 2.4 : 1.05,
                  isMobile: isMobile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCardsGrid extends StatelessWidget {
  final List<ServiceCardItem> cards;
  final int columns;
  final double spacing;
  final double aspectRatio;
  final bool isMobile;

  const _ServiceCardsGrid({
    required this.cards,
    required this.columns,
    required this.spacing,
    required this.aspectRatio,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final rowCount = (cards.length + columns - 1) ~/ columns;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) ...[
          if (rowIndex > 0) SizedBox(height: spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var colIndex = 0; colIndex < columns; colIndex++) ...[
                if (colIndex > 0) SizedBox(width: spacing),
                Expanded(
                  child: () {
                    final cardIndex = rowIndex * columns + colIndex;
                    if (cardIndex >= cards.length) {
                      // Keep column widths consistent across short rows.
                      return AspectRatio(
                        aspectRatio: aspectRatio,
                        child: const SizedBox.shrink(),
                      );
                    }
                    return AspectRatio(
                      aspectRatio: aspectRatio,
                      child: _ServiceCard(
                        card: cards[cardIndex],
                        isMobile: isMobile,
                      ),
                    );
                  }(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceCardItem card;
  final bool isMobile;

  const _ServiceCard({required this.card, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => launchCmsHref(context, card.href),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                  color: const Color(0xFF1B1B1B),
                ),
              ),
              if (card.body != null) ...[
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    card.body!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if ((card.ctaLabel ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF1B1B1B)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        card.ctaLabel!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: Color(0xFF1B1B1B),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
