// Detect and fill EN translation gaps for the catalog content collections.
//
// The storefront serves the default locale (fr) from the base columns and the
// secondary locale (en) from sibling `*_translations` collections. This script
// finds, for every base record that has French content, the localizable fields
// that have no English value yet, and lets you round-trip them through a CSV.
//
// Usage (run from the repo root, no extra deps — pure dart:io):
//
//   # 1. Read-only: list the gaps and write a translator-ready CSV.
//   dart run scripts/translation_gaps.dart detect
//   #   -> writes translation_gaps.csv (fr_value filled, en_value empty)
//
//   # 2. Fill the en_value column in translation_gaps.csv, then preview:
//   PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
//     dart run scripts/translation_gaps.dart import translation_gaps.csv
//
//   # 3. Actually write the translations back (creates/updates rows):
//   PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
//     dart run scripts/translation_gaps.dart import translation_gaps.csv --commit
//
// Detect is anonymous (the collections are public-read). Import needs a
// PocketBase superuser. Without --commit, import only prints the planned
// creates/updates (dry run). API_BASE_URL overrides the backend.

import 'dart:convert';
import 'dart:io';

const String _defaultBaseUrl = 'https://kiki-commerce.pockethost.io';
const String _targetLocale = 'en';

String get _baseUrl {
  final env = Platform.environment['API_BASE_URL']?.trim();
  final url = (env == null || env.isEmpty) ? _defaultBaseUrl : env;
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// One localizable base collection and its translation sibling.
class _Spec {
  final String base;
  final String translation;
  final String relation; // relation field on the translation row -> base id
  final List<String> fields; // localizable fields (first is required)
  final String referenceField; // human-friendly column in the base record
  final String? baseFilter;

  const _Spec(
    this.base,
    this.translation,
    this.relation,
    this.fields,
    this.referenceField, {
    this.baseFilter,
  });

  String get requiredField => fields.first;
}

const List<_Spec> _specs = [
  _Spec('products', 'product_translations', 'product', [
    'name',
    'summary',
    'description',
  ], 'code'),
  _Spec('categories', 'category_translations', 'category', [
    'name',
    'description',
  ], 'code'),
  _Spec(
    'narrativeChapters',
    'narrative_chapter_translations',
    'chapter',
    ['headline', 'story', 'ctaLabel'],
    'headline',
    baseFilter: 'isActive=true',
  ),
  _Spec('navigation_items', 'navigation_item_translations', 'item', [
    'label',
  ], 'label'),
];

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? '' : args.first;
  switch (mode) {
    case 'detect':
      await _detect();
    case 'import':
      if (args.length < 2) {
        stderr.writeln('usage: import <csv-file> [--commit]');
        exit(64);
      }
      await _import(args[1], commit: args.contains('--commit'));
    default:
      stderr.writeln(
        'usage: dart run scripts/translation_gaps.dart <detect|import> ...',
      );
      exit(64);
  }
}

// ---------------------------------------------------------------------------
// detect
// ---------------------------------------------------------------------------

Future<void> _detect() async {
  final client = HttpClient();
  final rows = <List<String>>[];
  stdout.writeln('Backend: $_baseUrl\n');
  stdout.writeln(
    '${'collection'.padRight(20)}${'base'.padLeft(5)}'
    '${'EN'.padLeft(5)}${'no EN'.padLeft(7)}${'partial'.padLeft(9)}',
  );
  stdout.writeln('-' * 46);

  for (final spec in _specs) {
    final baseRows = await _listAll(client, spec.base, filter: spec.baseFilter);
    final trRows = await _listAll(
      client,
      spec.translation,
      filter: 'locale="$_targetLocale"',
    );
    final byId = <String, Map<String, dynamic>>{
      for (final r in trRows) (r[spec.relation] as String? ?? ''): r,
    };

    var noEn = 0;
    var partial = 0;
    for (final b in baseRows) {
      final id = b['id'] as String? ?? '';
      final hasFr = spec.fields.any((f) => !_blank(b[f]));
      if (!hasFr) continue;
      final tr = byId[id];
      final missing = spec.fields
          .where((f) => !_blank(b[f]) && _blank(tr?[f]))
          .toList();
      if (missing.isEmpty) continue;
      if (tr == null) {
        noEn++;
      } else {
        partial++;
      }
      final reference = (b[spec.referenceField] as String? ?? '').trim();
      for (final field in missing) {
        rows.add([
          spec.base,
          id,
          reference,
          field,
          _stringValue(b[field]),
          '', // en_value: to be filled by the translator
        ]);
      }
    }
    stdout.writeln(
      '${spec.base.padRight(20)}${baseRows.length.toString().padLeft(5)}'
      '${trRows.length.toString().padLeft(5)}${noEn.toString().padLeft(7)}'
      '${partial.toString().padLeft(9)}',
    );
  }
  client.close();

  final out = File('translation_gaps.csv');
  final buffer = StringBuffer()
    ..writeln('collection,record_id,reference,field,fr_value,en_value');
  for (final row in rows) {
    buffer.writeln(row.map(_csvEscape).join(','));
  }
  out.writeAsStringSync(buffer.toString());
  stdout.writeln('\n${rows.length} champ(s) à traduire -> ${out.path}');
  stdout.writeln('Remplis la colonne en_value puis lance `import`.');
}

// ---------------------------------------------------------------------------
// import
// ---------------------------------------------------------------------------

Future<void> _import(String csvPath, {required bool commit}) async {
  final file = File(csvPath);
  if (!file.existsSync()) {
    stderr.writeln('Fichier introuvable: $csvPath');
    exit(66);
  }
  final parsed = _parseCsv(file.readAsStringSync());
  if (parsed.isEmpty) {
    stderr.writeln('CSV vide.');
    exit(65);
  }
  final header = parsed.first;
  final idx = {for (var i = 0; i < header.length; i++) header[i]: i};
  for (final col in ['collection', 'record_id', 'field', 'en_value']) {
    if (!idx.containsKey(col)) {
      stderr.writeln('Colonne manquante dans le CSV: $col');
      exit(65);
    }
  }

  // group: collection -> record_id -> {field: en_value}
  final grouped = <String, Map<String, Map<String, String>>>{};
  for (final row in parsed.skip(1)) {
    if (row.length < header.length) continue;
    final en = row[idx['en_value']!].trim();
    if (en.isEmpty) continue; // nothing translated on this line
    final coll = row[idx['collection']!].trim();
    final id = row[idx['record_id']!].trim();
    final field = row[idx['field']!].trim();
    grouped.putIfAbsent(coll, () => {}).putIfAbsent(id, () => {})[field] = en;
  }
  if (grouped.isEmpty) {
    stdout.writeln('Aucune valeur en_value renseignée — rien à importer.');
    return;
  }

  final client = HttpClient();
  String? token;
  if (commit) {
    token = await _authenticate(client);
  }

  var creates = 0;
  var updates = 0;
  for (final spec in _specs) {
    final groups = grouped[spec.base];
    if (groups == null) continue;

    // Existing EN rows so we know create-vs-update and the record id to PATCH.
    final existing = <String, Map<String, dynamic>>{
      for (final r in await _listAll(
        client,
        spec.translation,
        filter: 'locale="$_targetLocale"',
      ))
        (r[spec.relation] as String? ?? ''): r,
    };

    for (final entry in groups.entries) {
      final recordId = entry.key;
      final values = entry.value;
      final current = existing[recordId];
      if (current == null) {
        if (_blank(values[spec.requiredField])) {
          stdout.writeln(
            '  ⚠ ${spec.base}/$recordId: création ignorée '
            '(${spec.requiredField} EN requis manquant)',
          );
          continue;
        }
        creates++;
        final payload = {
          spec.relation: recordId,
          'locale': _targetLocale,
          ...values,
        };
        stdout.writeln('  + ${spec.translation} <- $recordId ${values.keys}');
        if (commit) {
          await _create(client, token!, spec.translation, payload);
        }
      } else {
        final changed = <String, String>{
          for (final e in values.entries)
            if (e.value.trim() != (current[e.key] as String? ?? '').trim())
              e.key: e.value,
        };
        if (changed.isEmpty) continue;
        updates++;
        stdout.writeln(
          '  ~ ${spec.translation} #${current['id']} ${changed.keys}',
        );
        if (commit) {
          await _update(
            client,
            token!,
            spec.translation,
            current['id'] as String,
            changed,
          );
        }
      }
    }
  }
  client.close();

  final verb = commit ? 'appliqués' : 'prévus (dry-run, ajoute --commit)';
  stdout.writeln('\n$creates création(s) + $updates mise(s) à jour $verb.');
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

Future<String> _authenticate(HttpClient client) async {
  final email = Platform.environment['PB_ADMIN_EMAIL'];
  final password = Platform.environment['PB_ADMIN_PASSWORD'];
  if (email == null || password == null) {
    stderr.writeln('Définis PB_ADMIN_EMAIL et PB_ADMIN_PASSWORD.');
    exit(78);
  }
  final res = await _send(
    client,
    'POST',
    '/api/collections/_superusers/auth-with-password',
    body: {'identity': email, 'password': password},
  );
  final token = res['token'] as String?;
  if (token == null || token.isEmpty) {
    stderr.writeln('Auth superuser échouée.');
    exit(77);
  }
  return token;
}

Future<List<Map<String, dynamic>>> _listAll(
  HttpClient client,
  String collection, {
  String? filter,
}) async {
  final items = <Map<String, dynamic>>[];
  var page = 1;
  while (true) {
    final query = {'perPage': '200', 'page': '$page', 'filter': ?filter};
    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await _send(
      client,
      'GET',
      '/api/collections/$collection/records?$qs',
    );
    for (final it in (data['items'] as List)) {
      items.add(it as Map<String, dynamic>);
    }
    final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
    if (page >= totalPages) break;
    page++;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return items;
}

Future<Map<String, dynamic>> _create(
  HttpClient client,
  String token,
  String collection,
  Map<String, dynamic> body,
) {
  return _send(
    client,
    'POST',
    '/api/collections/$collection/records',
    body: body,
    token: token,
  );
}

Future<Map<String, dynamic>> _update(
  HttpClient client,
  String token,
  String collection,
  String recordId,
  Map<String, dynamic> body,
) {
  return _send(
    client,
    'PATCH',
    '/api/collections/$collection/records/$recordId',
    body: body,
    token: token,
  );
}

/// Sends a request with exponential backoff on 403/429 (pockethost throttles
/// anonymous bursts) and returns the decoded JSON object.
Future<Map<String, dynamic>> _send(
  HttpClient client,
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  final uri = Uri.parse('$_baseUrl$path');
  for (var attempt = 0; ; attempt++) {
    final req = await client.openUrl(method, uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (token != null) req.headers.set(HttpHeaders.authorizationHeader, token);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return text.isEmpty ? const {} : jsonDecode(text) as Map<String, dynamic>;
    }
    if ((res.statusCode == 403 || res.statusCode == 429) && attempt < 5) {
      await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
      continue;
    }
    throw HttpException('$method $path -> ${res.statusCode}: $text');
  }
}

// ---------------------------------------------------------------------------
// CSV + value helpers
// ---------------------------------------------------------------------------

bool _blank(Object? v) => v == null || v.toString().trim().isEmpty;

String _stringValue(Object? v) => v is String ? v : (v?.toString() ?? '');

String _csvEscape(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Minimal RFC-4180 CSV parser (handles quotes, escaped quotes, newlines).
List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    if (row.any((f) => f.isNotEmpty)) rows.add(row);
  }
  return rows;
}
