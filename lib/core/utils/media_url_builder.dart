import '../../config/api_config.dart';

class MediaUrlBuilder {
  const MediaUrlBuilder._();

  static String fileUrl({
    required String collectionId,
    required String recordId,
    required String filename,
    String? version,
    String? baseUrl,
  }) {
    final resolvedBaseUrl = _normalizeBaseUrl(
      baseUrl ?? ApiConfig.mediaBaseUrl,
    );
    final url =
        '$resolvedBaseUrl/api/files/'
        '${Uri.encodeComponent(collectionId)}/'
        '${Uri.encodeComponent(recordId)}/'
        '${Uri.encodeComponent(filename)}';

    return _appendQuery(url, {
      if (version != null && version.trim().isNotEmpty) 'v': version.trim(),
    });
  }

  static String thumbUrl({
    required String collectionId,
    required String recordId,
    required String filename,
    required String size,
    String? version,
    String? baseUrl,
  }) {
    final url = fileUrl(
      collectionId: collectionId,
      recordId: recordId,
      filename: filename,
      version: null,
      baseUrl: baseUrl,
    );

    return _appendQuery(url, {
      'thumb': size,
      if (version != null && version.trim().isNotEmpty) 'v': version.trim(),
    });
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String _appendQuery(String url, Map<String, String> params) {
    if (params.isEmpty) return url;
    final uri = Uri.parse(url);
    return uri
        .replace(queryParameters: {...uri.queryParameters, ...params})
        .toString();
  }
}
