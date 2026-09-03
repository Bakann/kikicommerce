import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/media_image_support.dart';

/// A specialized image widget for Kiki Commerce that optimizes memory and performance.
///
/// It uses [CachedNetworkImage] for disk caching and automatically calculates
/// [memCacheWidth] and [memCacheHeight] based on the device's pixel ratio.
/// When width/height are not provided, falls back to a [LayoutBuilder] so the
/// decode resolution still matches the actual render size. If an ancestor
/// hands down an unbounded constraint on an axis (e.g. an unconstrained
/// scroll direction), that axis falls back to the screen size on the same
/// axis instead of decoding at the image's native resolution.
/// Supports both network URLs and raw bytes (for pending uploads).
class KikiImage extends StatelessWidget {
  /// Disk-cache bounds passed to the underlying provider. These are part of
  /// [CachedNetworkImageProvider]'s equality, so any caller that rebuilds the
  /// provider outside this widget must use the same values to hit the warm
  /// decoded [ImageCache] entry — see [cachedProviderFor].
  static const int defaultMaxWidthDiskCache = 2400;
  static const int defaultMaxHeightDiskCache = 2400;

  final String? imageUrl;
  final Uint8List? imageBytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeDuration;
  final int maxWidthDiskCache;
  final int maxHeightDiskCache;

  const KikiImage({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 180),
    this.maxWidthDiskCache = defaultMaxWidthDiskCache,
    this.maxHeightDiskCache = defaultMaxHeightDiskCache,
  });

  /// The exact decoded [ImageProvider] this widget resolves for [imageUrl] at
  /// an on-screen [renderSize].
  ///
  /// Mirrors the construction inside [_buildImage] (a memCache-sized
  /// [ResizeImage] over a disk-bounded [CachedNetworkImageProvider]) so a
  /// caller painting the same image outside the widget — e.g. the add-to-cart
  /// sticker overlay — reuses the warm [ImageCache] entry instead of forcing
  /// a re-decode. The disk bounds are part of the provider's `==`, so they
  /// must match: keep this in sync with [_buildImage].
  static ImageProvider cachedProviderFor({
    required String imageUrl,
    required Size renderSize,
    required double devicePixelRatio,
    int maxWidthDiskCache = defaultMaxWidthDiskCache,
    int maxHeightDiskCache = defaultMaxHeightDiskCache,
  }) {
    final cacheWidth = renderSize.width > 0
        ? (renderSize.width * devicePixelRatio).round()
        : null;
    final cacheHeight = renderSize.height > 0
        ? (renderSize.height * devicePixelRatio).round()
        : null;
    return ResizeImage.resizeIfNeeded(
      cacheWidth,
      cacheHeight,
      CachedNetworkImageProvider(
        imageUrl,
        maxWidth: maxWidthDiskCache,
        maxHeight: maxHeightDiskCache,
      ),
    );
  }

  bool _isBounded(double? v) => v != null && v > 0 && v != double.infinity;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null && imageBytes == null) {
      return errorWidget ?? _defaultErrorWidget();
    }
    if (imageUrl != null && imageUrl!.isEmpty && imageBytes == null) {
      return errorWidget ?? _defaultErrorWidget();
    }
    if (imageBytes == null && isKnownUnsupportedImageFormat(url: imageUrl)) {
      return errorWidget ?? _defaultErrorWidget();
    }

    if (_isBounded(width) && _isBounded(height)) {
      return _buildImage(context, width!, height!);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.sizeOf(context);
        final w = _isBounded(width)
            ? width!
            : (constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : screenSize.width);
        final h = _isBounded(height)
            ? height!
            : (constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : screenSize.height);
        return _buildImage(context, w, h);
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    double renderWidth,
    double renderHeight,
  ) {
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;

    final int? cacheWidth = renderWidth.isFinite && renderWidth > 0
        ? (renderWidth * pixelRatio).round()
        : null;
    final int? cacheHeight = renderHeight.isFinite && renderHeight > 0
        ? (renderHeight * pixelRatio).round()
        : null;

    if (imageBytes != null) {
      return Image.memory(
        imageBytes!,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
      fadeInDuration: fadeDuration,
      fadeOutDuration: fadeDuration,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorListener: (_) {},
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFCCCCCC),
          size: 24,
        ),
      ),
    );
  }
}
