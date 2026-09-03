import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:kiki_commerce/core/error/app_exception.dart';
import 'commercetools_catalog_product.dart';

/// Isolated HTTP client for the experimental commercetools catalog lab page.
///
/// Talks only to the public Cloudflare Worker (`kiki-ct-catalog-proxy`) — no
/// commercetools secret ever lives in Flutter. Deliberately separate from
/// [PocketBaseClient] so the lab integration stays reversible.
class CommercetoolsCatalogApi {
  static const Duration defaultTimeout = Duration(seconds: 10);

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  CommercetoolsCatalogApi({
    required http.Client client,
    required String baseUrl,
    Duration timeout = defaultTimeout,
  }) : _client = client,
       _baseUrl = baseUrl,
       _timeout = timeout;

  /// Fetches up to [limit] products from `GET {baseUrl}/products?limit=N`.
  ///
  /// Throws [ApiException] for an unusable base URL, non-200 responses, or a
  /// body that is not the expected `{ "items": [...] }` JSON shape.
  Future<List<CommercetoolsCatalogProduct>> fetchProducts({
    int limit = 20,
  }) async {
    final normalizedBase = _baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(normalizedBase);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      throw const ApiException('CT_CATALOG_PROXY_URL is not configured.');
    }

    final uri = Uri.parse(
      '$normalizedBase/products',
    ).replace(queryParameters: {'limit': '$limit'});

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on Object catch (error) {
      throw NetworkException(
        'Failed to reach the commercetools catalog proxy: $error',
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Commercetools catalog proxy returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw ApiException(
        'Commercetools catalog proxy returned malformed JSON: ${error.message}',
      );
    }

    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      throw const ApiException(
        'Commercetools catalog proxy response is missing an "items" list.',
      );
    }

    // Fail loudly on a malformed item rather than silently dropping it — the
    // lab page exists to diagnose the worker's JSON contract.
    return (decoded['items'] as List)
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const ApiException(
              'Commercetools catalog proxy response contains an invalid item.',
            );
          }
          return CommercetoolsCatalogProduct.fromJson(item);
        })
        .toList(growable: false);
  }
}
