import 'admin_backoffice_repository.dart';

class SaveAdminRecord {
  final AdminBackofficeRepository repository;

  const SaveAdminRecord(this.repository);

  Future<void> call({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
    String? recordId,
    String? mediaSource,
    String? mimeType,
    String fallbackFilename = 'media',
  }) async {
    if (collection == 'medias') {
      await repository.upsertMediaRecord(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: collection,
        recordId: recordId,
        data: data,
        mediaSource: mediaSource,
        fallbackFilename: fallbackFilename,
        mimeType: mimeType,
      );
      return;
    }

    if (recordId == null) {
      await repository.createRecord(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: collection,
        data: data,
      );
      return;
    }

    await repository.updateRecord(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: collection,
      recordId: recordId,
      data: data,
    );
  }
}
