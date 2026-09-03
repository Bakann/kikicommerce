import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/network/http_client_provider.dart';
import 'package:kiki_commerce/core/error/app_exception.dart';
import 'package:kiki_commerce/features/commercetools_lab/presentation/commercetools_lab_providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('commercetoolsListingItemsProvider', () {
    test('resolves to listing items with a valid proxy URL', () async {
      final container = ProviderContainer(
        overrides: [
          ctCatalogProxyUrlProvider.overrideWithValue(
            'https://proxy.example.dev',
          ),
          httpClientProvider.overrideWithValue(
            MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'items': [
                    {'id': 'p1', 'name': 'Bruno Chair', 'price': null},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(
        commercetoolsListingItemsProvider.future,
      );

      expect(items, hasLength(1));
      expect(items.single.product.name, 'Bruno Chair');
    });

    test('errors as not-configured for an absent/invalid proxy URL', () {
      final container = ProviderContainer(
        overrides: [ctCatalogProxyUrlProvider.overrideWithValue('')],
      );
      addTearDown(container.dispose);

      final result = container.read(commercetoolsListingItemsProvider);

      expect(result.hasError, isTrue);
      expect(result.error, isA<ApiException>());
      expect(
        (result.error! as ApiException).message,
        'CT_CATALOG_PROXY_URL is not configured.',
      );
    });
  });
}
