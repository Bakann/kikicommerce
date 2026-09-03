import '../../config/api_config.dart';
import '../../core/utils/media_url_builder.dart';

class MediaAsset {
  final String id;
  final String collectionId;
  final String? code;
  final String file;
  final String? originalFile;
  final String? altText;
  final String? mimeType;
  final String? title;
  final bool isActive;
  final String? cropPreset;
  final double? cropX;
  final double? cropY;
  final double? cropWidth;
  final double? cropHeight;
  final DateTime? updated;
  final String _baseUrl;

  const MediaAsset({
    required this.id,
    required this.collectionId,
    required this.file,
    this.originalFile,
    this.code,
    this.altText,
    this.mimeType,
    this.title,
    this.isActive = true,
    this.cropPreset,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.updated,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? ApiConfig.mediaBaseUrl;

  String? get version => updated?.toUtc().millisecondsSinceEpoch.toString();

  String get fileUrl => MediaUrlBuilder.fileUrl(
    collectionId: collectionId,
    recordId: id,
    filename: file,
    version: version,
    baseUrl: _baseUrl,
  );

  String? get originalFileUrl => originalFile == null || originalFile!.isEmpty
      ? null
      : MediaUrlBuilder.fileUrl(
          collectionId: collectionId,
          recordId: id,
          filename: originalFile!,
          version: version,
          baseUrl: _baseUrl,
        );

  String thumbUrl({String size = '300x300'}) => MediaUrlBuilder.thumbUrl(
    collectionId: collectionId,
    recordId: id,
    filename: file,
    size: size,
    version: version,
    baseUrl: _baseUrl,
  );

  factory MediaAsset.fromJson(Map<String, dynamic> json, {String? baseUrl}) {
    return MediaAsset(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      file: json['file'] as String? ?? '',
      originalFile: json['originalFile'] as String?,
      code: json['code'] as String?,
      altText: json['altText'] as String?,
      mimeType: json['mimeType'] as String?,
      title: json['title'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      cropPreset: json['cropPreset'] as String?,
      cropX: (json['cropX'] as num?)?.toDouble(),
      cropY: (json['cropY'] as num?)?.toDouble(),
      cropWidth: (json['cropWidth'] as num?)?.toDouble(),
      cropHeight: (json['cropHeight'] as num?)?.toDouble(),
      updated: _parseDateTime(json['updated']),
      baseUrl: baseUrl,
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
