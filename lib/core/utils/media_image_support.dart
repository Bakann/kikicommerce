const Set<String> _unsupportedImageMimeTypes = {
  'image/avif',
  'image/heic',
  'image/heif',
  'image/svg+xml',
  'image/tiff',
  'video/mp4',
  'video/quicktime',
  'video/webm',
};

const Set<String> _unsupportedImageExtensions = {
  'avif',
  'heic',
  'heif',
  'mov',
  'mp4',
  'm4v',
  'svg',
  'tif',
  'tiff',
  'webm',
};

bool isKnownUnsupportedImageFormat({String? url, String? mimeType}) {
  final normalizedMime = mimeType?.split(';').first.trim().toLowerCase();
  if (normalizedMime != null &&
      _unsupportedImageMimeTypes.contains(normalizedMime)) {
    return true;
  }

  final extension = _extensionFromUrl(url);
  return extension != null && _unsupportedImageExtensions.contains(extension);
}

String? _extensionFromUrl(String? url) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }

  final path = Uri.tryParse(url)?.path ?? url;
  final filename = path.split('/').last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == filename.length - 1) {
    return null;
  }

  return filename.substring(dotIndex + 1).toLowerCase();
}
