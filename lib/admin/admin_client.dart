import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/utils/media_url_builder.dart';

class PocketBaseMultipartFile {
  final String field;
  final Uint8List bytes;
  final String filename;

  const PocketBaseMultipartFile({
    required this.field,
    required this.bytes,
    required this.filename,
  });
}

class PocketBaseFieldSchema {
  final String name;
  final String type;
  final bool required;
  final int? maxSelect;
  final List<String> values;

  const PocketBaseFieldSchema({
    required this.name,
    required this.type,
    required this.required,
    required this.maxSelect,
    required this.values,
  });

  factory PocketBaseFieldSchema.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'] ?? json['options']?['values'];
    final rawMaxSelect = json['maxSelect'] ?? json['options']?['maxSelect'];

    return PocketBaseFieldSchema(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      maxSelect: rawMaxSelect is int
          ? rawMaxSelect
          : int.tryParse('$rawMaxSelect'),
      values: ((rawValues as List<dynamic>?) ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  bool get isMultiple =>
      type == 'relation' && maxSelect != null && maxSelect != 1;
}

class PocketBaseCollectionSchema {
  final String name;
  final Map<String, PocketBaseFieldSchema> fieldsByName;

  const PocketBaseCollectionSchema({
    required this.name,
    required this.fieldsByName,
  });

  factory PocketBaseCollectionSchema.fromJson(Map<String, dynamic> json) {
    final rawFields =
        (json['fields'] as List<dynamic>?) ??
        (json['schema'] as List<dynamic>?) ??
        const [];

    final fields = {
      for (final field in rawFields)
        if ((field as Map<String, dynamic>)['name'] != null)
          field['name'] as String: PocketBaseFieldSchema.fromJson(field),
    };

    return PocketBaseCollectionSchema(
      name: json['name'] as String? ?? '',
      fieldsByName: fields,
    );
  }
}

class PocketBaseAdminClient {
  final String baseUrl;
  final String? authToken;
  final http.Client _httpClient;

  PocketBaseAdminClient({
    required this.baseUrl,
    this.authToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Uri recordsUri(
    String collection, {
    Map<String, String>? queryParameters,
    String? recordId,
  }) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final encodedCollection = Uri.encodeComponent(collection);
    final path = recordId == null
        ? '/api/collections/$encodedCollection/records'
        : '/api/collections/$encodedCollection/records/${Uri.encodeComponent(recordId)}';
    return Uri.parse(
      '$normalizedBaseUrl$path',
    ).replace(queryParameters: queryParameters);
  }

  Uri authUri({String collection = '_superusers'}) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$normalizedBaseUrl/api/collections/${Uri.encodeComponent(collection)}/auth-with-password',
    );
  }

  Uri collectionUri(String collection) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(
      '$normalizedBaseUrl/api/collections/${Uri.encodeComponent(collection)}',
    );
  }

  String fileUrl(String collection, String recordId, String filename) {
    return MediaUrlBuilder.fileUrl(
      collectionId: collection,
      recordId: recordId,
      filename: filename,
      baseUrl: baseUrl,
    );
  }

  Future<String> authenticateSuperuser({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      authUri(),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'identity': email, 'password': password}),
    );

    final payload = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, response.statusCode));
    }

    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('PocketBase did not return an auth token.');
    }

    return token;
  }

  Future<String> authenticateUser({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      authUri(collection: 'users'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'identity': email, 'password': password}),
    );

    final payload = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, response.statusCode));
    }

    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('PocketBase did not return an auth token.');
    }

    return token;
  }

  Future<List<Map<String, dynamic>>> listRecords(
    String collection, {
    String sort = '-created',
    int perPage = 200,
    int page = 1,
    String? filter,
  }) async {
    final response = await _httpClient.get(
      recordsUri(
        collection,
        queryParameters: {
          'sort': sort,
          'page': '$page',
          'perPage': '$perPage',
          // ignore: use_null_aware_elements
          if (filter case final value?) 'filter': value,
        },
      ),
      headers: _headers(),
    );

    final payload = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, response.statusCode));
    }

    return ((payload['items'] as List<dynamic>?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<PocketBaseCollectionSchema> getCollectionSchema(
    String collection,
  ) async {
    final response = await _httpClient.get(
      collectionUri(collection),
      headers: _headers(),
    );

    final payload = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, response.statusCode));
    }

    return PocketBaseCollectionSchema.fromJson(payload);
  }

  Future<Map<String, dynamic>> createRecord(
    String collection,
    Map<String, dynamic> data,
  ) {
    return _sendJsonRequest(
      method: 'POST',
      uri: recordsUri(collection),
      data: data,
    );
  }

  Future<Map<String, dynamic>> updateRecord(
    String collection,
    String recordId,
    Map<String, dynamic> data,
  ) {
    return _sendJsonRequest(
      method: 'PATCH',
      uri: recordsUri(collection, recordId: recordId),
      data: data,
    );
  }

  Future<void> deleteRecord(String collection, String recordId) async {
    final response = await _httpClient.delete(
      recordsUri(collection, recordId: recordId),
      headers: _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = _decodeBody(response.body);
      throw Exception(_extractErrorMessage(payload, response.statusCode));
    }
  }

  Future<Map<String, dynamic>> upsertMultipartRecord({
    required String collection,
    String? recordId,
    required Map<String, dynamic> data,
    String fileField = 'file',
    Uint8List? fileBytes,
    String? filename,
    String? mimeType,
    List<PocketBaseMultipartFile> extraFiles = const [],
  }) async {
    final request = http.MultipartRequest(
      recordId == null ? 'POST' : 'PATCH',
      recordsUri(collection, recordId: recordId),
    );
    request.headers.addAll(_headers(includeContentType: false));

    for (final entry in data.entries) {
      final serialized = _serializeMultipartValue(entry.value);
      if (serialized != null) {
        request.fields[entry.key] = serialized;
      }
    }

    if (fileBytes != null && filename != null && filename.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(fileField, fileBytes, filename: filename),
      );
      if (mimeType != null && mimeType.isNotEmpty) {
        request.fields['mimeType'] = mimeType;
      }
    }

    for (final file in extraFiles) {
      request.files.add(
        http.MultipartFile.fromBytes(
          file.field,
          file.bytes,
          filename: file.filename,
        ),
      );
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();
    final payload = _decodeBody(body);

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(payload, streamedResponse.statusCode),
      );
    }

    return Map<String, dynamic>.from(payload);
  }

  Future<Map<String, dynamic>> _sendJsonRequest({
    required String method,
    required Uri uri,
    required Map<String, dynamic> data,
  }) async {
    late http.Response response;
    final encoded = jsonEncode(_normalizeJsonData(data));

    switch (method) {
      case 'POST':
        response = await _httpClient.post(
          uri,
          headers: _headers(),
          body: encoded,
        );
        break;
      case 'PATCH':
        response = await _httpClient.patch(
          uri,
          headers: _headers(),
          body: encoded,
        );
        break;
      default:
        throw UnsupportedError('Unsupported method: $method');
    }

    final payload = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, response.statusCode));
    }

    return Map<String, dynamic>.from(payload);
  }

  Map<String, dynamic> _normalizeJsonData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      result[entry.key] = _normalizeJsonValue(entry.value);
    }
    return result;
  }

  dynamic _normalizeJsonValue(dynamic value) {
    if (value is List) {
      return value.map(_normalizeJsonValue).toList();
    }
    if (value is String) {
      return value;
    }
    return value;
  }

  String? _serializeMultipartValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is List) {
      return jsonEncode(value);
    }
    return '$value';
  }

  Map<String, String> _headers({bool includeContentType = true}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = authToken!;
    }
    return headers;
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  String _extractErrorMessage(Map<String, dynamic> payload, int statusCode) {
    final message = payload['message'] as String?;
    final data = payload['data'];

    if (data is Map<String, dynamic> && data.isNotEmpty) {
      final details = data.entries
          .map((entry) {
            final fieldData = entry.value;
            if (fieldData is Map<String, dynamic>) {
              final fieldMessage = fieldData['message'] as String?;
              if (fieldMessage != null && fieldMessage.isNotEmpty) {
                return '${entry.key}: $fieldMessage';
              }
            }
            return '${entry.key}: ${entry.value}';
          })
          .join(' | ');

      if (message != null && message.isNotEmpty) {
        return '$message $details';
      }

      return details;
    }

    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'PocketBase request failed with status $statusCode.';
  }
}
