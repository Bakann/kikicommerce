import 'admin_backoffice_models.dart';
import 'admin_backoffice_repository.dart';

class LoadAdminCollections {
  final AdminBackofficeRepository repository;

  const LoadAdminCollections(this.repository);

  Future<AdminCollectionRecords> call({
    required String baseUrl,
    required String authToken,
    required List<AdminCollectionLoadRequest> collections,
  }) async {
    final recordsByCollection = <String, List<Map<String, dynamic>>>{};

    for (final collection in collections) {
      recordsByCollection[collection.name] = await repository.listRecords(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: collection.name,
        sort: collection.sort,
        perPage: collection.perPage,
      );
    }

    return recordsByCollection;
  }
}
