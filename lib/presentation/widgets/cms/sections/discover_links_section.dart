import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import '../../storefront_layout.dart';
import '../cms_href.dart';
import '../cms_text_reveal.dart';

class DiscoverLinksSection extends StatelessWidget {
  final DiscoverLinksConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const DiscoverLinksSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    if (config.links.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final columns = StorefrontLayout.isDesktop(width)
        ? config.columnsDesktop
        : config.columnsMobile;
    final sidePadding = StorefrontLayout.outerPaddingFor(
      width,
      maxWidth: StorefrontLayout.productListMaxWidth,
    );

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(sidePadding, 20, sidePadding, 42),
      child: CmsRevealGroup(
        key: textRevealId == null
            ? null
            : ValueKey('cms-discover-links-text-reveal-$textRevealId'),
        trigger: CmsRevealTrigger.viewport,
        enabled: enableTextReveal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config.title != null) ...[
            CmsRevealText(
              child: Text(
                config.title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F1F1C),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          CmsRevealText(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: config.links.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: StorefrontLayout.isDesktop(width) ? 4.6 : 7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final link = config.links[index];
                return OutlinedButton(
                  onPressed: () => launchCmsHref(context, link.href),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1F1F1C),
                    side: const BorderSide(color: Color(0xFFD8D4CA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    link.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
