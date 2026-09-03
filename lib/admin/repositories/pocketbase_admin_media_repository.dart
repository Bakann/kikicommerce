import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../application/admin/admin_media_repository.dart';
import '../../application/admin/media_crop_data.dart';
import '../admin_client.dart';

class PocketBaseAdminMediaRepository implements AdminMediaRepository {
  final String baseUrl;
  final http.Client? _httpClient;

  const PocketBaseAdminMediaRepository({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  @override
  Future<Uint8List> fetchBytes(String url) async {
    final client = _httpClient ?? http.Client();
    final response = await client.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Impossible de charger l’image source (${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  @override
  Future<void> replaceMedia({
    required String authToken,
    required String mediaId,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
    Uint8List? originalFileBytes,
    String? originalFilename,
    MediaCropData? cropData,
  }) async {
    final client = PocketBaseAdminClient(
      baseUrl: baseUrl,
      authToken: authToken,
    );
    final extraFiles = <PocketBaseMultipartFile>[];
    final data = <String, dynamic>{};

    if (originalFileBytes != null &&
        originalFilename != null &&
        originalFilename.isNotEmpty) {
      extraFiles.add(
        PocketBaseMultipartFile(
          field: 'originalFile',
          bytes: originalFileBytes,
          filename: originalFilename,
        ),
      );
    }

    if (cropData != null) {
      data['cropPreset'] = cropData.presetKey;
      data['cropX'] = cropData.x;
      data['cropY'] = cropData.y;
      data['cropWidth'] = cropData.width;
      data['cropHeight'] = cropData.height;
    }

    Future<void> upload({
      required Map<String, dynamic> requestData,
      List<PocketBaseMultipartFile> requestExtraFiles = const [],
    }) async {
      await client.upsertMultipartRecord(
        collection: 'medias',
        recordId: mediaId,
        data: requestData,
        fileField: 'file',
        fileBytes: fileBytes,
        filename: filename,
        mimeType: mimeType,
        extraFiles: requestExtraFiles,
      );
    }

    final hasOptionalPersistence = data.isNotEmpty || extraFiles.isNotEmpty;
    if (!hasOptionalPersistence) {
      await upload(requestData: const {});
      return;
    }

    try {
      await upload(requestData: data, requestExtraFiles: extraFiles);
    } catch (error) {
      final message = error.toString().toLowerCase();
      final isAuthorizationFailure =
          message.contains('not allowed to perform this action') ||
          message.contains('status 403') ||
          message.contains('unauthorized');

      if (isAuthorizationFailure) {
        rethrow;
      }

      await upload(requestData: const {});
    }
  }
}
