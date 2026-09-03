import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../application/cms/cms_models.dart';
import '../../kiki_image.dart';
import '../../landing_hero_video.dart';
import '../../storefront_layout.dart';
import '../cms_href.dart';

class EditorialStorySection extends StatelessWidget {
  final EditorialStoryConfig config;

  const EditorialStorySection({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isMobile = !isDesktop && !isTablet;

    final media = isMobile
        ? (config.mediaMobile ?? config.mediaDesktop)
        : (config.mediaDesktop ?? config.mediaMobile);

    final mediaWidget = _MediaPanel(media: media, mediaType: config.mediaType);
    final copyWidget = _CopyPanel(config: config, isMobile: isMobile);

    final background = switch (config.backgroundTone) {
      'sand' => const Color(0xFFF5EFE6),
      'dark' => const Color(0xFF1B1B1B),
      _ => Colors.white,
    };
    final isDarkBg = config.backgroundTone == 'dark';

    return Container(
      color: background,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 48 : 80,
        horizontal: isMobile ? 24 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: isDarkBg ? Colors.white : const Color(0xFF1B1B1B),
                displayColor: isDarkBg ? Colors.white : const Color(0xFF1B1B1B),
              ),
            ),
            child: isMobile
                ? _MobileLayout(
                    media: mediaWidget,
                    copy: copyWidget,
                    layoutVariant: config.layoutVariant,
                  )
                : _DesktopLayout(
                    media: mediaWidget,
                    copy: copyWidget,
                    layoutVariant: config.layoutVariant,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final Widget media;
  final Widget copy;
  final String layoutVariant;

  const _DesktopLayout({
    required this.media,
    required this.copy,
    required this.layoutVariant,
  });

  @override
  Widget build(BuildContext context) {
    final mediaFirst = layoutVariant != 'mediaRight';
    final children = mediaFirst
        ? [
            Expanded(child: media),
            const SizedBox(width: 56),
            Expanded(child: Center(child: copy)),
          ]
        : [
            Expanded(child: Center(child: copy)),
            const SizedBox(width: 56),
            Expanded(child: media),
          ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final Widget media;
  final Widget copy;
  final String layoutVariant;

  const _MobileLayout({
    required this.media,
    required this.copy,
    required this.layoutVariant,
  });

  @override
  Widget build(BuildContext context) {
    final children = layoutVariant == 'mediaBottom'
        ? [copy, const SizedBox(height: 24), media]
        : [media, const SizedBox(height: 24), copy];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _MediaPanel extends StatelessWidget {
  final CmsMediaRef? media;
  final String mediaType;

  const _MediaPanel({required this.media, required this.mediaType});

  @override
  Widget build(BuildContext context) {
    if (mediaType == 'none') {
      return const SizedBox.shrink();
    }
    if (media == null || !media!.isUsable) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(color: const Color(0xFFEDEAE3)),
      );
    }
    if (mediaType == 'video' || media!.isVideo) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: LandingHeroVideo(videoUrl: media!.fileUrl()),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: KikiImage(
        imageUrl: media!.thumbUrl(size: '1200x1500f'),
        fit: BoxFit.cover,
        placeholder: Container(color: const Color(0xFFEDEAE3)),
        errorWidget: Container(color: const Color(0xFFEDEAE3)),
      ),
    );
  }
}

class _CopyPanel extends StatelessWidget {
  final EditorialStoryConfig config;
  final bool isMobile;

  const _CopyPanel({required this.config, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final ctaColor =
        Theme.of(context).textTheme.bodyMedium?.color ??
        const Color(0xFF1B1B1B);
    if (config.eyebrow != null) {
      children.add(
        Text(
          config.eyebrow!,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.6,
          ),
        ),
      );
      children.add(const SizedBox(height: 14));
    }
    if (config.title.isNotEmpty) {
      children.add(
        Text(
          config.title,
          style: GoogleFonts.cormorantGaramond(
            fontSize: isMobile ? 30 : 42,
            fontWeight: FontWeight.w400,
            height: 1.1,
          ),
        ),
      );
    }
    if (config.body != null) {
      children.add(const SizedBox(height: 18));
      children.add(
        Text(config.body!, style: const TextStyle(fontSize: 15, height: 1.55)),
      );
    }
    if (config.primaryCta?.isUsable == true) {
      children.add(const SizedBox(height: 22));
      children.add(
        TextButton(
          onPressed: () => launchCmsHref(context, config.primaryCta!.href),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            foregroundColor: ctaColor,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ctaColor)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(config.primaryCta!.label),
            ),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
