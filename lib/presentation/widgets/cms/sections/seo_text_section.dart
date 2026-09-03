import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import '../../storefront_layout.dart';
import '../cms_text_reveal.dart';

class SeoTextSection extends StatelessWidget {
  final SeoTextConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const SeoTextSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    if (config.title == null && config.body == null) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        StorefrontLayout.outerPaddingFor(
          width,
          maxWidth: StorefrontLayout.productListMaxWidth,
        ),
        24,
        StorefrontLayout.outerPaddingFor(
          width,
          maxWidth: StorefrontLayout.productListMaxWidth,
        ),
        32,
      ),
      child: CmsRevealGroup(
        key: textRevealId == null
            ? null
            : ValueKey('cms-seo-text-reveal-$textRevealId'),
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
            const SizedBox(height: 10),
          ],
          if (config.body != null)
            CmsRevealText(
              child: Text(
                config.body!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: Color(0xFF5F5D57),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
