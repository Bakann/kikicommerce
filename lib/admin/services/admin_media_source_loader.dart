import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ResolvedAdminMediaSource {
  final Uint8List bytes;
  final String filename;

  const ResolvedAdminMediaSource({required this.bytes, required this.filename});
}

class AdminMediaSourceLoader {
  const AdminMediaSourceLoader();

  Future<ResolvedAdminMediaSource?> load(
    String source, {
    required String fallbackFilename,
    String? mimeType,
  }) async {
    if (source.trim().isEmpty) {
      return null;
    }

    if (source.startsWith('asset://')) {
      final assetPath = source.substring('asset://'.length);
      final data = await rootBundle.load(assetPath);
      return ResolvedAdminMediaSource(
        bytes: data.buffer.asUint8List(),
        filename: filenameFromSource(
          source,
          fallbackFilename: fallbackFilename,
          mimeType: mimeType,
        ),
      );
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      final response = await http.get(Uri.parse(source));
      if (response.statusCode != 200) {
        throw Exception(
          'Téléchargement impossible (${response.statusCode}) pour $source',
        );
      }
      return ResolvedAdminMediaSource(
        bytes: response.bodyBytes,
        filename: filenameFromSource(
          source,
          fallbackFilename: fallbackFilename,
          mimeType: mimeType,
        ),
      );
    }

    throw Exception(
      'Source média non supportée: $source. Utilisez asset:// ou http(s)://.',
    );
  }

  String filenameFromSource(
    String source, {
    required String fallbackFilename,
    String? mimeType,
  }) {
    final sanitized = source.split('/').last.split('?').first;
    if (sanitized.contains('.')) {
      return sanitized;
    }
    return '$fallbackFilename${_extensionFromMimeType(mimeType)}';
  }

  String _extensionFromMimeType(String? mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/webp':
        return '.webp';
      case 'image/svg+xml':
        return '.svg';
      case 'image/png':
      default:
        return '.png';
    }
  }
}
