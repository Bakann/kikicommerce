import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/media_upload_guidance.dart';
import 'media_crop_data.dart';
import 'web_image_encoder.dart';

class OptimizedMediaUpload {
  final Uint8List fileBytes;
  final String filename;
  final String? mimeType;
  final int originalBytes;
  final bool wasOptimized;

  const OptimizedMediaUpload({
    required this.fileBytes,
    required this.filename,
    required this.mimeType,
    required this.originalBytes,
    required this.wasOptimized,
  });
}

class OptimizeMediaUpload {
  const OptimizeMediaUpload();

  Future<OptimizedMediaUpload> cropAndOptimize({
    required Uint8List sourceBytes,
    required String filename,
    required MediaCropData cropData,
    bool forceOpaque = false,
  }) async {
    // On web, the browser's native canvas pipeline (decode + drawImage +
    // toBlob) is orders of magnitude faster than `package:image` running
    // on the main thread. The conditional import returns null off-web or
    // on any failure, falling back to the Dart pipeline below.
    if (forceOpaque) {
      final canvasResult = await encodeOpaqueJpegWithCanvas(
        sourceBytes: sourceBytes,
        filename: filename,
        cropData: cropData,
        recommendedLongEdge: mediaUploadRecommendedLongEdge,
      );
      if (canvasResult != null) {
        return canvasResult;
      }
    }

    // NOTE: on Flutter Web, `compute()` does not actually offload to a
    // worker — it runs synchronously on the main thread.
    final payload = await compute(_cropAndOptimizeEntry, {
      'sourceBytes': sourceBytes,
      'filename': filename,
      'presetKey': cropData.presetKey,
      'x': cropData.x,
      'y': cropData.y,
      'width': cropData.width,
      'height': cropData.height,
      'forceOpaque': forceOpaque,
    });

    return OptimizedMediaUpload(
      fileBytes: payload['fileBytes'] as Uint8List,
      filename: payload['filename'] as String,
      mimeType: payload['mimeType'] as String?,
      originalBytes: payload['originalBytes'] as int,
      wasOptimized: payload['wasOptimized'] as bool,
    );
  }

  OptimizedMediaUpload call({
    required Uint8List fileBytes,
    required String filename,
    bool forceOpaque = false,
  }) {
    final originalMimeType = _mimeTypeFromFilename(filename);
    final decoded = _decodeOrientedImage(fileBytes);
    if (decoded == null) {
      return OptimizedMediaUpload(
        fileBytes: fileBytes,
        filename: filename,
        mimeType: originalMimeType,
        originalBytes: fileBytes.lengthInBytes,
        wasOptimized: false,
      );
    }

    final sourceFormat = img.findFormatForData(fileBytes);
    final normalized = _normalizeToWebSafe(
      decoded: decoded,
      sourceBytes: fileBytes,
      sourceFormat: sourceFormat,
      filename: filename,
    );

    final flatImage = forceOpaque ? _flattenOnWhite(decoded) : decoded;

    final result = _optimizeDecodedImage(
      image: flatImage,
      filename: normalized.filename,
      originalBytes: normalized.bytes.lengthInBytes,
      originalEncodedBytes: normalized.bytes,
      originalMimeType: normalized.mimeType,
      forceOpaque: forceOpaque,
    );

    if (normalized.transcoded && !result.wasOptimized) {
      return OptimizedMediaUpload(
        fileBytes: result.fileBytes,
        filename: result.filename,
        mimeType: result.mimeType,
        originalBytes: fileBytes.lengthInBytes,
        wasOptimized: true,
      );
    }
    return result;
  }
}

Map<String, dynamic> _cropAndOptimizeEntry(Map<String, dynamic> args) {
  final sourceBytes = args['sourceBytes'] as Uint8List;
  final filename = args['filename'] as String;
  final forceOpaque = args['forceOpaque'] as bool? ?? false;
  final cropData = MediaCropData(
    presetKey: args['presetKey'] as String,
    x: args['x'] as double,
    y: args['y'] as double,
    width: args['width'] as double,
    height: args['height'] as double,
  );

  final decoded = _decodeOrientedImage(sourceBytes);
  if (decoded == null) {
    return {
      'fileBytes': sourceBytes,
      'filename': filename,
      'mimeType': _mimeTypeFromFilename(filename),
      'originalBytes': sourceBytes.lengthInBytes,
      'wasOptimized': false,
    };
  }

  final cropped = _cropImage(decoded, cropData);

  // forceOpaque short-circuit: resize first, flatten, encode JPEG once.
  // Skips the full-resolution baseline encode that the generic path needs
  // for size comparison — a major freeze source on large RGBA sources.
  if (forceOpaque) {
    final longest = math.max(cropped.width, cropped.height);
    final sized = longest > mediaUploadRecommendedLongEdge
        ? _resizeToMaxEdge(cropped)
        : cropped;
    final flat = _flattenOnWhite(sized);
    final jpgBytes = Uint8List.fromList(img.encodeJpg(flat, quality: 82));
    final outFilename = _replaceExtension(filename, 'jpg');
    return {
      'fileBytes': jpgBytes,
      'filename': outFilename,
      'mimeType': 'image/jpeg',
      'originalBytes': jpgBytes.lengthInBytes,
      'wasOptimized': true,
    };
  }

  final sourceFormat = img.findFormatForData(sourceBytes);
  final effectiveFormat = _isWebRenderableFormat(sourceFormat)
      ? sourceFormat
      : img.ImageFormat.png;
  final effectiveFilename = _isWebRenderableFormat(sourceFormat)
      ? filename
      : _replaceExtension(filename, 'png');
  final originalEncoded = _encodeWithOriginalFormat(
    cropped,
    sourceFormat: effectiveFormat,
  );

  final optimized = _optimizeDecodedImage(
    image: cropped,
    filename: effectiveFilename,
    originalBytes: originalEncoded.lengthInBytes,
    originalEncodedBytes: originalEncoded,
    originalMimeType: _mimeTypeFromSourceFormat(
      effectiveFormat,
      effectiveFilename,
    ),
    forceOpaque: false,
  );

  return {
    'fileBytes': optimized.fileBytes,
    'filename': optimized.filename,
    'mimeType': optimized.mimeType,
    'originalBytes': optimized.originalBytes,
    'wasOptimized': optimized.wasOptimized,
  };
}

img.Image? _decodeOrientedImage(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }

  return switch (decoded.exif.exifIfd.orientation ?? -1) {
    3 => img.copyRotate(decoded, angle: 180),
    6 => img.copyRotate(decoded, angle: 90),
    8 => img.copyRotate(decoded, angle: -90),
    _ => decoded,
  };
}

img.Image _cropImage(img.Image image, MediaCropData cropData) {
  final left = (cropData.x * image.width).round().clamp(0, image.width - 1);
  final top = (cropData.y * image.height).round().clamp(0, image.height - 1);
  final width = math.max(1, (cropData.width * image.width).round());
  final height = math.max(1, (cropData.height * image.height).round());
  final safeWidth = math.min(width, image.width - left);
  final safeHeight = math.min(height, image.height - top);

  return img.copyCrop(
    image,
    x: left,
    y: top,
    width: safeWidth,
    height: safeHeight,
  );
}

OptimizedMediaUpload _optimizeDecodedImage({
  required img.Image image,
  required String filename,
  required int originalBytes,
  required Uint8List originalEncodedBytes,
  required String? originalMimeType,
  bool forceOpaque = false,
}) {
  final original = OptimizedMediaUpload(
    fileBytes: originalEncodedBytes,
    filename: filename,
    mimeType: originalMimeType,
    originalBytes: originalBytes,
    wasOptimized: false,
  );

  final longestEdge = math.max(image.width, image.height);
  final shouldResize = longestEdge > mediaUploadRecommendedLongEdge;
  final shouldReencode = originalBytes > mediaUploadRecommendedMaxBytes;

  if (!shouldResize && !shouldReencode) {
    return original;
  }

  final workingImage = shouldResize ? _resizeToMaxEdge(image) : image;
  final candidate = _encodeCandidate(
    image: workingImage,
    originalBytes: originalBytes,
    originalFilename: filename,
    forceOpaque: forceOpaque,
  );

  if (candidate == null) {
    return original;
  }

  return candidate;
}

img.Image _resizeToMaxEdge(img.Image image) {
  if (image.width >= image.height) {
    return img.copyResize(image, width: mediaUploadRecommendedLongEdge);
  }

  return img.copyResize(image, height: mediaUploadRecommendedLongEdge);
}

OptimizedMediaUpload? _encodeCandidate({
  required img.Image image,
  required int originalBytes,
  required String originalFilename,
  bool forceOpaque = false,
}) {
  if (image.hasAlpha && !forceOpaque) {
    final pngBytes = Uint8List.fromList(img.encodePng(image, level: 6));
    if (pngBytes.lengthInBytes >= originalBytes) {
      return null;
    }

    return OptimizedMediaUpload(
      fileBytes: pngBytes,
      filename: _replaceExtension(originalFilename, 'png'),
      mimeType: 'image/png',
      originalBytes: originalBytes,
      wasOptimized: true,
    );
  }

  // For forceOpaque, accept the JPEG even if it's slightly larger than the
  // original — emitting JPEG is the explicit caller choice (faster encode,
  // browser-cacheable, and avoids the PNG main-thread freeze on web).
  for (final quality in const [82, 74, 66]) {
    final jpgBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    if (forceOpaque || jpgBytes.lengthInBytes < originalBytes) {
      return OptimizedMediaUpload(
        fileBytes: jpgBytes,
        filename: _replaceExtension(originalFilename, 'jpg'),
        mimeType: 'image/jpeg',
        originalBytes: originalBytes,
        wasOptimized: true,
      );
    }
  }

  return null;
}

Uint8List _encodeWithOriginalFormat(
  img.Image image, {
  required img.ImageFormat sourceFormat,
}) {
  return switch (sourceFormat) {
    img.ImageFormat.jpg => Uint8List.fromList(img.encodeJpg(image)),
    img.ImageFormat.png => Uint8List.fromList(img.encodePng(image)),
    img.ImageFormat.webp => Uint8List.fromList(img.encodePng(image)),
    img.ImageFormat.bmp => Uint8List.fromList(img.encodeBmp(image)),
    img.ImageFormat.ico => Uint8List.fromList(img.encodeIco(image)),
    _ => Uint8List.fromList(img.encodePng(image)),
  };
}

String _replaceExtension(String filename, String newExtension) {
  final sanitized = filename.trim();
  final dotIndex = sanitized.lastIndexOf('.');
  final baseName = dotIndex <= 0 ? sanitized : sanitized.substring(0, dotIndex);
  return '$baseName.$newExtension';
}

String? _mimeTypeFromFilename(String filename) {
  final normalized = filename.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  if (normalized.endsWith('.gif')) {
    return 'image/gif';
  }
  if (normalized.endsWith('.mp4')) {
    return 'video/mp4';
  }
  return null;
}

String? _mimeTypeFromSourceFormat(img.ImageFormat format, String filename) {
  return switch (format) {
    img.ImageFormat.jpg => 'image/jpeg',
    img.ImageFormat.png => 'image/png',
    img.ImageFormat.webp => 'image/webp',
    img.ImageFormat.bmp => 'image/bmp',
    img.ImageFormat.ico => 'image/x-icon',
    _ => _mimeTypeFromFilename(filename),
  };
}

bool _isWebRenderableFormat(img.ImageFormat format) {
  return switch (format) {
    img.ImageFormat.jpg ||
    img.ImageFormat.png ||
    img.ImageFormat.webp ||
    img.ImageFormat.gif ||
    img.ImageFormat.bmp => true,
    _ => false,
  };
}

class _NormalizedSource {
  final Uint8List bytes;
  final String filename;
  final String? mimeType;
  final bool transcoded;

  const _NormalizedSource({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.transcoded,
  });
}

/// Composites the image over a solid white background and drops the alpha
/// channel. Used by callers that know the rendered context is opaque
/// (e.g. landing hero) so we can take the lighter JPEG encode path instead
/// of the heavy PNG zlib deflate.
img.Image _flattenOnWhite(img.Image image) {
  if (!image.hasAlpha) {
    return image;
  }
  final flat = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  );
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, image);
  return flat;
}

/// Ensures the baseline bytes uploaded to storage are in a format that
/// both Flutter's `Image` widget and the PocketBase thumbnailer can render.
/// Sources like TIFF are transcoded to PNG and the filename is updated
/// to match, so downstream consumers don't see a `.tiff` file on disk.
_NormalizedSource _normalizeToWebSafe({
  required img.Image decoded,
  required Uint8List sourceBytes,
  required img.ImageFormat sourceFormat,
  required String filename,
}) {
  if (_isWebRenderableFormat(sourceFormat)) {
    return _NormalizedSource(
      bytes: sourceBytes,
      filename: filename,
      mimeType: _mimeTypeFromSourceFormat(sourceFormat, filename),
      transcoded: false,
    );
  }

  final pngBytes = Uint8List.fromList(img.encodePng(decoded));
  return _NormalizedSource(
    bytes: pngBytes,
    filename: _replaceExtension(filename, 'png'),
    mimeType: 'image/png',
    transcoded: true,
  );
}
