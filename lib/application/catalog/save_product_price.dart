import '../../domain/catalog/catalog_entities.dart';
import '../admin/admin_backoffice_repository.dart';
import '../admin/save_admin_record.dart';

sealed class SaveProductPriceResult {
  const SaveProductPriceResult();
}

class SaveProductPriceNoChange extends SaveProductPriceResult {
  const SaveProductPriceNoChange();
}

class SaveProductPriceSaved extends SaveProductPriceResult {
  const SaveProductPriceSaved();
}

class SaveProductPriceFailure extends SaveProductPriceResult {
  final Object error;

  const SaveProductPriceFailure(this.error);
}

class SaveProductPrice {
  final SaveAdminRecord saveAdminRecord;
  final AdminBackofficeRepository adminBackofficeRepository;

  const SaveProductPrice(this.saveAdminRecord, this.adminBackofficeRepository);

  Future<SaveProductPriceResult> call({
    required String baseUrl,
    required String authToken,
    required String productId,
    CatalogPrice? priceRow,
    required double price,
  }) async {
    final normalizedPrice = normalizeProductPrice(price);
    if (priceRow != null &&
        isSameProductPrice(priceRow.price, normalizedPrice)) {
      return const SaveProductPriceNoChange();
    }

    try {
      if (priceRow == null) {
        final currencyId = await _resolveCurrencyId(
          baseUrl: baseUrl,
          authToken: authToken,
        );
        await saveAdminRecord(
          baseUrl: baseUrl,
          authToken: authToken,
          collection: 'priceRows',
          data: {
            'product': productId,
            'currency': currencyId,
            'price': normalizedPrice,
            'isDefault': true,
            'isActive': true,
          },
        );
        return const SaveProductPriceSaved();
      }

      await saveAdminRecord(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'priceRows',
        recordId: priceRow.id,
        data: {'price': normalizedPrice},
      );
      return const SaveProductPriceSaved();
    } catch (error) {
      return SaveProductPriceFailure(error);
    }
  }

  Future<String> _resolveCurrencyId({
    required String baseUrl,
    required String authToken,
  }) async {
    final currencies = await adminBackofficeRepository.listRecords(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: 'currencies',
      sort: 'isocode',
      perPage: 100,
      filter: 'isActive=true',
    );
    if (currencies.isEmpty) {
      throw StateError(
        'Aucune devise active n’est disponible pour créer un prix.',
      );
    }

    final preferred = currencies.firstWhere(
      (record) => _stringValue(record['isocode']).toUpperCase() == 'EUR',
      orElse: () => currencies.first,
    );
    final currencyId = _stringValue(preferred['id']);
    if (currencyId.isEmpty) {
      throw StateError('La devise sélectionnée pour le prix est invalide.');
    }
    return currencyId;
  }
}

double normalizeProductPrice(double price) =>
    double.parse(price.toStringAsFixed(2));

bool isSameProductPrice(double currentPrice, double nextPrice) {
  return (normalizeProductPrice(currentPrice) -
              normalizeProductPrice(nextPrice))
          .abs() <
      0.0001;
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';
