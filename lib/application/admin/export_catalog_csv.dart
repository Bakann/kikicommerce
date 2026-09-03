import 'admin_backoffice_repository.dart';
import 'catalog_export_result.dart';

class ExportCatalogCsv {
  final AdminBackofficeRepository repository;

  const ExportCatalogCsv(this.repository);

  Future<CatalogExportResult> call({
    required String baseUrl,
    required String authToken,
  }) {
    return repository.exportCatalogCsv(baseUrl: baseUrl, authToken: authToken);
  }
}
