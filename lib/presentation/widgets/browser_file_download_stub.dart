Future<void> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
  bool includeBom = false,
}) {
  throw UnsupportedError(
    'Le téléchargement direct de fichiers n’est disponible que sur Flutter web.',
  );
}
