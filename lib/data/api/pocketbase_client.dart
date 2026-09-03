import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/error/app_exception.dart';
import '../../core/utils/media_url_builder.dart';
import '../models/paginated_response.dart';

class PocketBaseClient {
  final http.Client httpClient;
  final String baseUrl;
  final Future<void> Function(Duration delay) _delay;
  final Duration _retryBaseDelay;
  final Duration _rateLimitBaseDelay;
  late final _GetRequestQueue _getQueue;
  DateTime _rateLimitedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  PocketBaseClient({
    required this.httpClient,
    required this.baseUrl,
    int maxConcurrentGets = 4,
    Future<void> Function(Duration delay)? delay,
    Duration retryBaseDelay = const Duration(milliseconds: 250),
    Duration rateLimitBaseDelay = const Duration(milliseconds: 800),
  }) : _delay = delay ?? Future<void>.delayed,
       _retryBaseDelay = retryBaseDelay,
       _rateLimitBaseDelay = rateLimitBaseDelay {
    _getQueue = _GetRequestQueue(maxConcurrentGets);
  }

  String _recordsUrl(String collection) =>
      '$baseUrl/api/collections/${Uri.encodeComponent(collection)}/records';

  String _recordUrl(String collection, String id) =>
      '$baseUrl/api/collections/${Uri.encodeComponent(collection)}/records/${Uri.encodeComponent(id)}';

  String _customUrl(String path) => '$baseUrl$path';

  // These helpers intentionally use the API origin. Public storefront media
  // URLs should use MediaAsset/CmsMediaRef with MediaUrlBuilder against the
  // CDN base URL.
  String fileUrl(String collectionId, String recordId, String filename) =>
      MediaUrlBuilder.fileUrl(
        collectionId: collectionId,
        recordId: recordId,
        filename: filename,
        baseUrl: baseUrl,
      );

  String thumbUrl(
    String collectionId,
    String recordId,
    String filename, {
    String size = '400x0',
  }) => MediaUrlBuilder.thumbUrl(
    collectionId: collectionId,
    recordId: recordId,
    filename: filename,
    size: size,
    baseUrl: baseUrl,
  );

  Future<Map<String, dynamic>> getRecord(
    String collection,
    String id, {
    String? expand,
    String? authToken,
    String? cartGuestId,
  }) async {
    final uri = Uri.parse(
      _recordUrl(collection, id),
    ).replace(queryParameters: {'expand': ?expand});

    final response = await _get(
      uri,
      authToken: authToken,
      cartGuestId: cartGuestId,
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<PaginatedResponse<T>> listRecords<T>(
    String collection, {
    String? filter,
    String? sort,
    String? expand,
    String? fields,
    int? page,
    int? perPage,
    String? authToken,
    String? cartGuestId,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final uri = Uri.parse(_recordsUrl(collection)).replace(
      queryParameters: {
        'filter': ?filter,
        'sort': ?sort,
        'expand': ?expand,
        'fields': ?fields,
        'page': ?page?.toString(),
        'perPage': ?perPage?.toString(),
      },
    );

    final response = await _get(
      uri,
      authToken: authToken,
      cartGuestId: cartGuestId,
    );
    return PaginatedResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      fromJson,
    );
  }

  Future<Map<String, dynamic>> createRecord(
    String collection,
    Map<String, dynamic> body, {
    String? authToken,
    String? cartGuestId,
  }) {
    return _send(
      method: 'POST',
      uri: Uri.parse(_recordsUrl(collection)),
      body: body,
      authToken: authToken,
      cartGuestId: cartGuestId,
    );
  }

  Future<Map<String, dynamic>> sendJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? authToken,
    String? cartGuestId,
    Map<String, String>? extraHeaders,
  }) {
    return _send(
      method: method,
      uri: Uri.parse(_customUrl(path)),
      body: body,
      authToken: authToken,
      cartGuestId: cartGuestId,
      extraHeaders: extraHeaders,
    );
  }

  Future<Map<String, dynamic>> updateRecord(
    String collection,
    String id,
    Map<String, dynamic> body, {
    String? authToken,
    String? cartGuestId,
  }) {
    return _send(
      method: 'PATCH',
      uri: Uri.parse(_recordUrl(collection, id)),
      body: body,
      authToken: authToken,
      cartGuestId: cartGuestId,
    );
  }

  Future<void> deleteRecord(
    String collection,
    String id, {
    String? authToken,
    String? cartGuestId,
  }) async {
    await _send(
      method: 'DELETE',
      uri: Uri.parse(_recordUrl(collection, id)),
      authToken: authToken,
      cartGuestId: cartGuestId,
    );
  }

  Future<http.Response> _get(
    Uri uri, {
    String? authToken,
    String? cartGuestId,
    Map<String, String>? extraHeaders,
  }) async {
    return _getQueue.run(
      () => _retryGet(() async {
        await _waitForRateLimitCooldown();
        final response = await httpClient.get(
          uri,
          headers: _headers(
            authToken: authToken,
            cartGuestId: cartGuestId,
            extraHeaders: extraHeaders,
            includeContentType: false,
          ),
        );
        if (!_isSuccess(response.statusCode)) {
          throw _apiExceptionFromResponse(response);
        }
        return response;
      }),
    );
  }

  Future<T> _retryGet<T>(Future<T> Function() action) async {
    int attempts = 0;
    while (true) {
      try {
        return await action();
      } on ApiException catch (e) {
        if (e.statusCode != 429 || attempts >= 2) rethrow;
        _markRateLimited(attempts + 1);
      } on SocketException catch (e) {
        if (attempts >= 2) {
          throw NetworkException('Network error: ${e.message}');
        }
      } on http.ClientException catch (e) {
        if (attempts >= 2) {
          throw NetworkException('Network error: ${e.message}');
        }
        if (_isLikelyCorsPreflightFailure(e)) {
          _markRateLimited(attempts + 1);
        }
      } on TimeoutException catch (e) {
        if (attempts >= 2) {
          throw NetworkException(
            e.message == null
                ? 'Network timeout'
                : 'Network timeout: ${e.message}',
          );
        }
      }
      attempts++;
      await _delay(_retryDelay(attempts));
    }
  }

  bool _isLikelyCorsPreflightFailure(http.ClientException error) {
    final message = error.message.toLowerCase();
    return message.contains('cors') ||
        message.contains('xmlhttprequest') ||
        message.contains('failed to fetch');
  }

  void _markRateLimited(int attempt) {
    final next = DateTime.now().add(_rateLimitDelay(attempt));
    if (next.isAfter(_rateLimitedUntil)) {
      _rateLimitedUntil = next;
    }
  }

  Future<void> _waitForRateLimitCooldown() async {
    final wait = _rateLimitedUntil.difference(DateTime.now());
    if (wait > Duration.zero) {
      await _delay(wait);
    }
  }

  Duration _retryDelay(int attempt) {
    return Duration(milliseconds: _retryBaseDelay.inMilliseconds * attempt);
  }

  Duration _rateLimitDelay(int attempt) {
    return Duration(milliseconds: _rateLimitBaseDelay.inMilliseconds * attempt);
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
    String? authToken,
    String? cartGuestId,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final encodedBody = body == null ? null : jsonEncode(body);
      final headers = _headers(
        authToken: authToken,
        cartGuestId: cartGuestId,
        extraHeaders: extraHeaders,
        includeContentType: encodedBody != null,
      );
      final response = switch (method) {
        'POST' => await httpClient.post(
          uri,
          headers: headers,
          body: encodedBody,
        ),
        'PATCH' => await httpClient.patch(
          uri,
          headers: headers,
          body: encodedBody,
        ),
        'DELETE' => await httpClient.delete(uri, headers: headers),
        _ => throw UnsupportedError('Unsupported method: $method'),
      };

      if (!_isSuccess(response.statusCode)) {
        throw _apiExceptionFromResponse(response);
      }

      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on SocketException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error: ${e.message}');
    }
  }

  bool _isSuccess(int code) => code >= 200 && code < 300;

  ApiException _apiExceptionFromResponse(http.Response response) {
    final parsedBody = _tryParseJsonObject(response.body);
    final message =
        (parsedBody?['message'] as String?) ??
        'API error: ${response.statusCode}';
    return ApiException(
      message,
      statusCode: response.statusCode,
      data: parsedBody,
    );
  }

  Map<String, dynamic>? _tryParseJsonObject(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // Ignore non-JSON error bodies and surface the status code instead.
    }

    return null;
  }

  Map<String, String> _headers({
    String? authToken,
    String? cartGuestId,
    Map<String, String>? extraHeaders,
    bool includeContentType = true,
  }) {
    return {
      'Accept': 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty) 'Authorization': authToken,
      if (cartGuestId != null && cartGuestId.isNotEmpty)
        'X-Cart-Guest-Id': cartGuestId,
      ...?extraHeaders,
    };
  }
}

class _GetRequestQueue {
  final int maxConcurrent;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  int _active = 0;

  _GetRequestQueue(int maxConcurrent)
    : maxConcurrent = maxConcurrent < 1 ? 1 : maxConcurrent;

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < maxConcurrent) {
      _active += 1;
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _active -= 1;
  }
}
