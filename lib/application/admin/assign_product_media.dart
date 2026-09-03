import '../../config/api_config.dart';
import 'admin_backoffice_repository.dart';

class AssignProductMedia {
  final AdminBackofficeRepository repository;

  const AssignProductMedia(this.repository);

  /// Reassigns the main picture of a product to a different media record.
  Future<void> call({
    required String authToken,
    required String productId,
    required String mediaId,
  }) async {
    await repository.updateRecord(
      baseUrl: ApiConfig.apiBaseUrl,
      authToken: authToken,
      collection: 'products',
      recordId: productId,
      data: {'picture': mediaId},
    );
  }
}
