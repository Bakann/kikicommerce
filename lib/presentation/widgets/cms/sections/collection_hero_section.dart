import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../application/cms/cms_models.dart';
import '../../kiki_image.dart';
import '../../storefront_layout.dart';
import '../cms_text_reveal.dart';

class CollectionHeroSection extends StatelessWidget {
  final CollectionHeroConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const CollectionHeroSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    if (config.title.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final media = isDesktop
        ? (config.imageDesktop ?? config.imageMobile)
        : (config.imageMobile ?? config.imageDesktop);
    final image = media == null
        ? null
        : KikiImage(
            imageUrl: media.thumbUrl(size: isDesktop ? '1400x900' : '800x1000'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        StorefrontLayout.horizontalPaddingFor(width),
        isDesktop ? 48 : 28,
        StorefrontLayout.horizontalPaddingFor(width),
        isDesktop ? 42 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: isDesktop && config.desktopLayout == 'split'
              ? Row(
                  children: [
                    Expanded(
                      child: _Copy(
                        config: config,
                        isDesktop: true,
                        enableTextReveal: enableTextReveal,
                        textRevealId: textRevealId,
                      ),
                    ),
                    const SizedBox(width: 40),
                    if (image != null)
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: _ratio(config.aspectRatio, 4 / 5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: image,
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (image != null && config.mobileLayout != 'textOnly') ...[
                      AspectRatio(
                        aspectRatio: _ratio(config.aspectRatio, 4 / 5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: image,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _Copy(
                      config: config,
                      isDesktop: isDesktop,
                      enableTextReveal: enableTextReveal,
                      textRevealId: textRevealId,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  final CollectionHeroConfig config;
  final bool isDesktop;
  final bool enableTextReveal;
  final String? textRevealId;

  const _Copy({
    required this.config,
    required this.isDesktop,
    required this.enableTextReveal,
    required this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    return CmsRevealGroup(
      key: textRevealId == null
          ? null
          : ValueKey('cms-collection-hero-text-reveal-$textRevealId'),
      trigger: CmsRevealTrigger.viewport,
      enabled: enableTextReveal,
      crossAxisAlignment: isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        CmsRevealText(
          child: Text(
            config.title,
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: isDesktop ? 44 : 34,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1F1F1C),
            ),
          ),
        ),
        if (config.intro != null) ...[
          const SizedBox(height: 12),
          CmsRevealText(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                config.intro!,
                textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF5F5D57),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

double _ratio(String value, double fallback) {
  final raw = value.trim();
  if (raw.contains('/')) {
    final parts = raw.split('/');
    if (parts.length == 2) {
      final left = double.tryParse(parts[0].trim());
      final right = double.tryParse(parts[1].trim());
      if (left != null && right != null && right > 0) {
        return left / right;
      }
    }
  }
  return double.tryParse(raw) ?? fallback;
}
