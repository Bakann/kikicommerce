import 'dart:developer' as developer;

import '../../application/storefront/storefront_brand_settings.dart';
import '../../application/storefront/storefront_navigation_settings.dart';
import '../../application/storefront/storefront_theme.dart';
import '../api/pocketbase_client.dart';

const _logName = 'storefront-settings';

class PocketBaseStorefrontSettingsRepository
    implements StorefrontSettingsRepository {
  final PocketBaseClient client;

  PocketBaseStorefrontSettingsRepository({required this.client});

  // Distinguishes "no record yet" (expected startup state, silent
  // fallback) from a technical failure (logged with stack trace).
  // Misdiagnosing backend outages as "use the fallback" was hiding
  // incidents from operators. `dart:developer.log` keeps the data
  // layer free of any Flutter UI dependency.
  void _logFailure(String op, Object error, StackTrace stack) {
    developer.log(
      '$op failed; falling back',
      name: _logName,
      error: error,
      stackTrace: stack,
    );
  }

  @override
  Future<StorefrontBrandSettings> getBrandSettings() async {
    try {
      final page = await client.listRecords<StorefrontBrandSettings>(
        storefrontSettingsCollection,
        filter: 'key = "$storefrontBrandSettingsKey"',
        sort: '+id',
        perPage: 1,
        fromJson: StorefrontBrandSettings.fromJson,
      );
      if (page.items.isEmpty) {
        return StorefrontBrandSettings.fallback;
      }
      return page.items.first;
    } catch (error, stack) {
      _logFailure('getBrandSettings', error, stack);
      return StorefrontBrandSettings.fallback;
    }
  }

  @override
  Future<StorefrontNavigationSettings> getNavigationSettings() async {
    try {
      final page = await client.listRecords<StorefrontNavigationSettings>(
        storefrontSettingsCollection,
        filter: 'key = "$storefrontNavigationSettingsKey"',
        sort: '+id',
        perPage: 1,
        fromJson: StorefrontNavigationSettings.fromJson,
      );
      if (page.items.isEmpty) {
        return StorefrontNavigationSettings.fallback;
      }
      return page.items.first;
    } catch (error, stack) {
      _logFailure('getNavigationSettings', error, stack);
      return StorefrontNavigationSettings.fallback;
    }
  }

  @override
  Future<StorefrontActiveTheme> getActiveTheme() async {
    try {
      // Sort by +id so reads are stable across calls and clients even in
      // the brief window where the unique-key migration hasn't yet run and
      // duplicates could still exist. Once the index is in place there's
      // at most one record and the sort is moot.
      final page = await client.listRecords<StorefrontActiveTheme>(
        storefrontSettingsCollection,
        filter: 'key = "$storefrontActiveThemeKey"',
        sort: '+id',
        perPage: 1,
        fromJson: StorefrontActiveTheme.fromJson,
      );
      if (page.items.isEmpty) return StorefrontActiveTheme.fallback;
      return page.items.first;
    } catch (error, stack) {
      _logFailure('getActiveTheme', error, stack);
      return StorefrontActiveTheme.fallback;
    }
  }

  @override
  Future<void> saveActiveTheme({
    required String authToken,
    required StorefrontTheme theme,
    String? existingRecordId,
  }) async {
    final payload = StorefrontActiveTheme(
      id: existingRecordId,
      theme: theme,
    ).toPayload();

    final activeThemeRecords = await _findActiveThemeRecords(authToken);
    // Reuse the caller-provided id, otherwise reuse the first existing
    // record so we PATCH instead of POST. If no record exists we fall
    // through to a create.
    final recordId = existingRecordId ?? _firstNonEmptyId(activeThemeRecords);
    final shouldUpdate = recordId != null && recordId.isNotEmpty;

    final saved = shouldUpdate
        ? await client.updateRecord(
            storefrontSettingsCollection,
            recordId,
            payload,
            authToken: authToken,
          )
        : await client.createRecord(
            storefrontSettingsCollection,
            payload,
            authToken: authToken,
          );

    final savedId = (saved['id'] as String?)?.trim();
    if (savedId != null && savedId.isNotEmpty) {
      await _deleteDuplicateActiveThemeRecords(
        records: activeThemeRecords,
        keepRecordId: savedId,
        authToken: authToken,
      );
    }
  }

  String? _firstNonEmptyId(List<Map<String, dynamic>> records) {
    for (final record in records) {
      final id = (record['id'] as String?)?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _findActiveThemeRecords(
    String authToken,
  ) async {
    final page = await client.listRecords<Map<String, dynamic>>(
      storefrontSettingsCollection,
      filter: 'key = "$storefrontActiveThemeKey"',
      sort: '+id',
      perPage: 200,
      authToken: authToken,
      fromJson: (json) => json,
    );
    return page.items;
  }

  Future<void> _deleteDuplicateActiveThemeRecords({
    required List<Map<String, dynamic>> records,
    required String keepRecordId,
    required String authToken,
  }) async {
    for (final record in records) {
      final id = (record['id'] as String?)?.trim();
      if (id == null || id.isEmpty || id == keepRecordId) continue;
      await client.deleteRecord(
        storefrontSettingsCollection,
        id,
        authToken: authToken,
      );
    }
  }
}
