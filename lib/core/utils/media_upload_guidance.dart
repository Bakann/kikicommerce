enum MediaUploadAdvisoryLevel { info, warning, error }

const mediaUploadRecommendedMaxBytes = 2 * 1024 * 1024;
const mediaUploadPocketBaseMaxBytes = 8 * 1024 * 1024;
const mediaUploadRecommendedLongEdge = 1600;

class MediaUploadAdvisory {
  final MediaUploadAdvisoryLevel level;
  final String title;
  final String message;
  final bool canUpload;

  const MediaUploadAdvisory({
    required this.level,
    required this.title,
    required this.message,
    required this.canUpload,
  });
}

MediaUploadAdvisory advisoryForImageUpload(int bytes) {
  if (bytes > mediaUploadPocketBaseMaxBytes) {
    return const MediaUploadAdvisory(
      level: MediaUploadAdvisoryLevel.error,
      title: 'Image très lourde',
      message:
          'Le fichier dépasse 8 Mo. L’app tentera de l’optimiser avant l’upload, mais si le résultat final reste au-dessus de 8 Mo, il faudra le réduire manuellement.',
      canUpload: true,
    );
  }

  if (bytes > mediaUploadRecommendedMaxBytes) {
    return const MediaUploadAdvisory(
      level: MediaUploadAdvisoryLevel.warning,
      title: 'Image publiable mais lourde',
      message:
          'L’upload reste possible, mais il sera plus lent et les thumbnails coûteront plus cher à générer. Visez plutôt moins de 2 Mo, en WebP ou JPEG, avec un côté long proche de 1600 px.',
      canUpload: true,
    );
  }

  return const MediaUploadAdvisory(
    level: MediaUploadAdvisoryLevel.info,
    title: 'Image dans la cible',
    message:
        'Le poids est cohérent pour le storefront. Gardez si possible un export WebP ou JPEG et un côté long proche de 1600 px.',
    canUpload: true,
  );
}

String formatBytesForHumans(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  final precision = value >= 100 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}
