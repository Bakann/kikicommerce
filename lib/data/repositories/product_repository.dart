import 'dart:async';

import '../../application/catalog/catalog_read_models.dart';
import '../../application/catalog/product_catalog_repository.dart';
import '../../core/error/app_exception.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../api/pocketbase_client.dart';
import '../mappers/catalog_mappers.dart';
import '../models/narrative_chapter.dart';
import '../models/paginated_response.dart';
import '../models/price_row.dart';
import '../models/product.dart';
import '_translation_fetcher.dart';

class PocketBaseProductRepository implements ProductCatalogRepository {
  static const Duration defaultProductTimeout = Duration(seconds: 8);
  static const Duration defaultSecondaryTimeout = Duration(seconds: 3);

  final PocketBaseClient client;
  final Duration productTimeout;
  final Duration secondaryTimeout;

  PocketBaseProductRepository({
    required this.client,
    this.productTimeout = defaultProductTimeout,
    this.secondaryTimeout = defaultSecondaryTimeout,
  });

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) async {
    final Map<String, dynamic> productJson;
    try {
      productJson = await client
          .getRecord(
            'products',
            productId,
            expand: 'picture,thumbnail,galleryImages,galleryImages.medias',
          )
          .timeout(productTimeout);
    } on TimeoutException {
      throw const NetworkException('Le chargement du produit a expiré.');
    }

    final product = Product.fromJson(productJson);
    final escapedProductId = escapeFilterValue(productId);
    final pricesFuture = _loadOptionalList<PriceRow>(
      client.listRecords<PriceRow>(
        'priceRows',
        filter: 'product="$escapedProductId" && isActive=true',
        expand: 'currency',
        perPage: 50,
        fromJson: PriceRow.fromJson,
      ),
    );
    final chaptersFuture = _loadOptionalList<NarrativeChapterRecord>(
      client.listRecords<NarrativeChapterRecord>(
        'narrativeChapters',
        filter: 'product="$escapedProductId" && isActive=true',
        sort: 'position',
        perPage: 50,
        fromJson: NarrativeChapterRecord.fromJson,
      ),
    );
    final translationsFuture = fetchProductTranslations(client, [
      product.id,
    ], locale: locale);
    final prices = await pricesFuture;
    final chapters = await chaptersFuture;
    final translations = await translationsFuture;
    // Chapter ids are only known once chapters resolve; the fetch is a no-op
    // for the default locale and for products without a narrative.
    final chapterTranslations = await fetchNarrativeChapterTranslations(
      client,
      [for (final chapter in chapters) chapter.id],
      locale: locale,
    );

    return ProductDetailData(
      product: toCatalogProduct(product, translation: translations[product.id]),
      prices: prices.map(toCatalogPrice).toList(),
      chapters: chapters
          .map(
            (chapter) => toNarrativeChapter(
              chapter,
              translation: chapterTranslations[chapter.id],
            ),
          )
          .toList(),
    );
  }

  Future<List<T>> _loadOptionalList<T>(
    Future<PaginatedResponse<T>> request,
  ) async {
    try {
      final response = await request.timeout(secondaryTimeout);
      return response.items;
    } on Exception {
      return const [];
    }
  }
}
