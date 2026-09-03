import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import '../../kiki_image.dart';
import '../../landing_hero_video.dart';
import '../../storefront_layout.dart';
import '../cms_href.dart';
import '../cms_text_reveal.dart';

const _heroMediaFallbackColor = Color(0xFFF4F1EA);

class HeroCampaignSection extends StatelessWidget {
  final HeroCampaignConfig config;
  final String? backgroundFallbackImageUrl;
  final bool enableTextReveal;
  final String? textRevealId;

  const HeroCampaignSection({
    super.key,
    required this.config,
    this.backgroundFallbackImageUrl,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isMobile = !isTablet && !isDesktop;

    final media = isMobile
        ? (config.mediaMobile ?? config.mediaDesktop)
        : (config.mediaDesktop ?? config.mediaMobile);

    final isSquare = config.heightMode == 'square';

    // The dark gradient only earns its place when there is copy to keep legible.
    // An image-only hero (e.g. the 1:1 PLP hero) then stays clean, and looks the
    // same in edit mode and on the storefront.
    final hasCopy =
        (config.eyebrow?.isNotEmpty ?? false) ||
        config.title.trim().isNotEmpty ||
        (config.subtitle?.isNotEmpty ?? false) ||
        (config.body?.isNotEmpty ?? false) ||
        (config.primaryCta?.isUsable ?? false);

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        _HeroBackground(
          media: media,
          mediaType: config.mediaType,
          imageThumbSize: isSquare ? '1080x1080f' : '1800x1200f',
          fallbackImageUrl: backgroundFallbackImageUrl,
        ),
        if (hasCopy)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000),
                  Color(0x10000000),
                  Color(0x99000000),
                ],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
        if (hasCopy)
          Positioned(
            left: 24,
            right: 24,
            bottom: isMobile ? 56 : 72,
            child: _HeroCopy(
              config: config,
              isMobile: isMobile,
              enableTextReveal: enableTextReveal,
              textRevealId: textRevealId,
            ),
          ),
      ],
    );

    // 'square' renders a full-bleed 1:1 hero (the PLP hero). Other modes keep
    // their viewport-fraction height.
    if (isSquare) {
      return AspectRatio(aspectRatio: 1, child: stack);
    }

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = HeroCampaignSection.heightFor(
      mode: config.heightMode,
      viewportHeight: viewportHeight,
      isMobile: isMobile,
    );
    return SizedBox(height: maxHeight, width: double.infinity, child: stack);
  }

  static double heightFor({
    required String mode,
    required double viewportHeight,
    required bool isMobile,
  }) {
    final fraction = switch (mode) {
      'sm' => 0.35,
      'md' => 0.5,
      'lg' => 0.65,
      _ => isMobile ? 0.7 : 0.78,
    };
    final raw = viewportHeight * fraction;
    if (isMobile) {
      return raw.clamp(360.0, 720.0);
    }
    return raw.clamp(420.0, 880.0);
  }
}

class _HeroBackground extends StatelessWidget {
  final CmsMediaRef? media;
  final String mediaType;
  final String imageThumbSize;
  final String? fallbackImageUrl;

  const _HeroBackground({
    required this.media,
    required this.mediaType,
    required this.imageThumbSize,
    required this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackUrl = fallbackImageUrl?.trim();
    final hasFallback = fallbackUrl != null && fallbackUrl.isNotEmpty;

    if (media == null || !media!.isUsable) {
      return const ColoredBox(color: _heroMediaFallbackColor);
    }
    if (mediaType == 'video' || media!.isVideo) {
      return LandingHeroVideo(videoUrl: media!.fileUrl());
    }
    final configuredImage = KikiImage(
      imageUrl: media!.thumbUrl(size: imageThumbSize),
      fit: BoxFit.cover,
      placeholder: hasFallback
          ? const SizedBox.expand()
          : const ColoredBox(color: _heroMediaFallbackColor),
      errorWidget: hasFallback
          ? const SizedBox.expand()
          : const ColoredBox(color: _heroMediaFallbackColor),
    );

    if (!hasFallback) {
      return configuredImage;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _HeroFallbackImage(imageUrl: fallbackUrl),
        configuredImage,
      ],
    );
  }
}

class _HeroFallbackImage extends StatelessWidget {
  final String imageUrl;

  const _HeroFallbackImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Image(
      image: NetworkImage(imageUrl),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: _heroMediaFallbackColor),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final HeroCampaignConfig config;
  final bool isMobile;
  final bool enableTextReveal;
  final String? textRevealId;

  const _HeroCopy({
    required this.config,
    required this.isMobile,
    required this.enableTextReveal,
    required this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    final align = switch (config.textAlign) {
      'left' => CrossAxisAlignment.start,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    final textAlign = switch (config.textAlign) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };

    final hasTitle = config.title.trim().isNotEmpty;
    final children = <Widget>[];

    if (config.eyebrow != null) {
      children.add(
        CmsRevealText(
          child: Text(
            config.eyebrow!,
            textAlign: textAlign,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.6,
            ),
          ),
        ),
      );
    }
    if (config.subtitle != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 10));
      children.add(
        CmsRevealText(
          child: Text(
            config.subtitle!,
            textAlign: textAlign,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }
    if (hasTitle) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 14));
      children.add(
        CmsRevealText(
          child: Text(
            config.title,
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              color: Colors.white,
              fontSize: isMobile ? 38 : 56,
              fontWeight: FontWeight.w400,
              height: 1.05,
            ),
          ),
        ),
      );
    }
    if (config.body != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      children.add(
        CmsRevealText(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              config.body!,
              textAlign: textAlign,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    if (config.primaryCta?.isUsable == true) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 22));
      children.add(CmsRevealText(child: _HeroCta(cta: config.primaryCta!)));
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return CmsRevealGroup(
      key: textRevealId == null
          ? null
          : ValueKey('cms-hero-text-reveal-$textRevealId'),
      trigger: CmsRevealTrigger.mount,
      enabled: enableTextReveal,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: children,
    );
  }
}

class _HeroCta extends StatelessWidget {
  final CmsCta cta;

  const _HeroCta({required this.cta});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => launchCmsHref(context, cta.href),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(cta.label),
        ),
      ),
    );
  }
}
