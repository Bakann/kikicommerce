import 'admin_backoffice_repository.dart';
import 'catalog_import_report.dart';

class ImportCatalogCsv {
  final AdminBackofficeRepository repository;

  const ImportCatalogCsv(this.repository);

  Future<CatalogImportReport> call({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) {
    return repository.importCatalogCsv(
      baseUrl: baseUrl,
      authToken: authToken,
      csvContent: csvContent,
    );
  }
}
