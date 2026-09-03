import 'admin_backoffice_repository.dart';

class DeleteAdminRecord {
  final AdminBackofficeRepository repository;

  const DeleteAdminRecord(this.repository);

  Future<void> call({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) {
    return repository.deleteRecord(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: collection,
      recordId: recordId,
    );
  }
}
