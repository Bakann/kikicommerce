import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/product_foil_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _record({String mask = 'mask_x.webp'}) => {
  'id': 'rec123456789012',
  'collectionId': 'pbc_314159',
  'collectionName': 'product_foils',
  'product_id': 'prod12345678901',
  'foil': 'foil_a.webp',
  'mask': mask,
  'source_image':
      'https://kiki-commerce.pockethost.io/api/files/pbc_633459407/'
      'media9876543210/photo.jpg?thumb=600x800f',
  'preset': {
    'effect': 'uncommon reverse holo',
    'maskVariant': 'background',
    'intensity': 1.2,
  },
  'updated': '2026-07-18 10:00:00.000Z',
};

Map<String, dynamic> _volumeRecord() => {
  ..._record(),
  'product_image': 'product_image.webp',
  'subject_mask': 'subject_mask.webp',
  'background_clean': 'background_clean.webp',
  'rim': 'rim.webp',
  'depth_map': 'depth_map.webp',
  'depth_mesh': {
    'model': 'depth-anything/Depth-Anything-V2-Small-hf',
    'columns': 2,
    'rows': 2,
    'values': [-1, 0, 0.5, 1],
  },
  'particles': [
    [0.25, 0.5, 0.8],
  ],
  'preset': {
    'effect': 'uncommon reverse holo',
    'maskVariant': 'background',
    'intensity': 1.2,
    'parallax': true,
    'volume': true,
    'particles': true,
  },
};

PocketBaseClient _client(
  Future<http.Response> Function(http.Request) handler,
) => PocketBaseClient(
  httpClient: MockClient(handler),
  baseUrl: 'https://example.test',
);

void main() {
  test('fetchForProduct returns the parsed foil with file URLs', () async {
    late Uri requested;
    final repository = ProductFoilRepository(
      client: _client((request) async {
        requested = request.url;
        return http.Response(
          jsonEncode({
            'page': 1,
            'perPage': 1,
            'totalItems': 1,
            'totalPages': 1,
            'items': [_record()],
          }),
          200,
        );
      }),
    );

    final foil = await repository.fetchForProduct('prod12345678901');

    expect(requested.path, contains('/collections/product_foils/records'));
    expect(requested.queryParameters['filter'], "product_id='prod12345678901'");
    expect(foil, isNotNull);
    expect(foil!.intensity, closeTo(1.2, 1e-9));
    // File URLs target the record's own collection/id and carry the
    // `updated` stamp as the cache-busting version.
    expect(foil.foilUrl, contains('/api/files/pbc_314159/rec123456789012/'));
    expect(foil.foilUrl, contains('foil_a.webp'));
    expect(foil.foilUrl, contains('v=2026-07-18'));
    expect(foil.maskUrl, contains('mask_x.webp'));
    // The foil only applies to the media it was generated from.
    expect(foil.matchesMediaId('media9876543210'), isTrue);
    expect(foil.matchesMediaId('someothermedia1'), isFalse);
  });

  test('an empty mask filename maps to null (partout variant)', () async {
    final repository = ProductFoilRepository(
      client: _client((request) async {
        return http.Response(
          jsonEncode({
            'page': 1,
            'perPage': 1,
            'totalItems': 1,
            'totalPages': 1,
            'items': [_record(mask: '')],
          }),
          200,
        );
      }),
    );

    final foil = await repository.fetchForProduct('prod12345678901');

    expect(foil!.maskUrl, isNull);
  });

  test('parses the optional 2.5D runtime bundle', () async {
    final repository = ProductFoilRepository(
      client: _client((request) async {
        return http.Response(
          jsonEncode({
            'page': 1,
            'perPage': 1,
            'totalItems': 1,
            'totalPages': 1,
            'items': [_volumeRecord()],
          }),
          200,
        );
      }),
    );

    final foil = await repository.fetchForProduct('prod12345678901');

    expect(foil, isNotNull);
    expect(foil!.hasParallaxBundle, isTrue);
    expect(foil.hasVolumeBundle, isTrue);
    expect(foil.hasParticleBundle, isTrue);
    expect(foil.productImageUrl, contains('product_image.webp'));
    expect(foil.subjectMaskUrl, contains('subject_mask.webp'));
    expect(foil.backgroundCleanUrl, contains('background_clean.webp'));
    expect(foil.rimUrl, contains('rim.webp'));
    expect(foil.depthMapUrl, contains('depth_map.webp'));
    expect(foil.depthMesh!.sample(0, 0), -1);
    expect(foil.depthMesh!.sample(1, 1), 1);
    expect(foil.particles.single.brightness, 0.8);
  });

  test('invalid depth JSON falls back to two-plane parallax', () async {
    final record = _volumeRecord();
    record['depth_mesh'] = {
      'columns': 3,
      'rows': 3,
      'values': [0, 1],
    };
    final repository = ProductFoilRepository(
      client: _client((request) async {
        return http.Response(
          jsonEncode({
            'page': 1,
            'perPage': 1,
            'totalItems': 1,
            'totalPages': 1,
            'items': [record],
          }),
          200,
        );
      }),
    );

    final foil = await repository.fetchForProduct('prod12345678901');

    expect(foil!.hasParallaxBundle, isTrue);
    expect(foil.hasVolumeBundle, isFalse);
    expect(foil.depthMesh, isNull);
  });

  test('fetchForProduct resolves null when no record exists', () async {
    final repository = ProductFoilRepository(
      client: _client((request) async {
        return http.Response(
          jsonEncode({
            'page': 1,
            'perPage': 1,
            'totalItems': 0,
            'totalPages': 0,
            'items': [],
          }),
          200,
        );
      }),
    );

    expect(await repository.fetchForProduct('unknown'), isNull);
  });

  test(
    'fetchForProduct resolves null on errors (missing collection)',
    () async {
      final repository = ProductFoilRepository(
        client: _client((request) async {
          return http.Response('{"message":"Missing collection"}', 404);
        }),
      );

      expect(await repository.fetchForProduct('prod12345678901'), isNull);
    },
  );
}
