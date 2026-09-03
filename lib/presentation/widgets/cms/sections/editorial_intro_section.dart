import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../application/cms/cms_models.dart';
import '../../storefront_layout.dart';
import '../cms_text_reveal.dart';

class EditorialIntroSection extends StatelessWidget {
  final EditorialIntroConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const EditorialIntroSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    if (config.title.trim().isEmpty && config.body == null) {
      return const SizedBox.shrink();
    }
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: StorefrontLayout.horizontalPaddingFor(width),
        vertical: StorefrontLayout.isDesktop(width) ? 44 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: CmsRevealGroup(
            key: textRevealId == null
                ? null
                : ValueKey('cms-editorial-intro-text-reveal-$textRevealId'),
            trigger: CmsRevealTrigger.viewport,
            enabled: enableTextReveal,
            children: [
              if (config.eyebrow != null) ...[
                CmsRevealText(
                  child: Text(
                    config.eyebrow!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      color: Color(0xFF77736A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (config.title.trim().isNotEmpty)
                CmsRevealText(
                  child: Text(
                    config.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: StorefrontLayout.isDesktop(width) ? 34 : 28,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF1F1F1C),
                    ),
                  ),
                ),
              if (config.body != null) ...[
                const SizedBox(height: 12),
                CmsRevealText(
                  child: Text(
                    config.body!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: Color(0xFF5F5D57),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
