import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../admin/admin_collection_schema.dart';
import '../../app/app_providers.dart';
import '../../application/admin/admin_backoffice_models.dart';
import '../../application/admin/catalog_export_result.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../core/utils/search_index_utils.dart';
import 'catalog_invalidator_provider.dart';

class AdminBackofficeState {
  final AdminCollectionRecords recordsByCollection;
  final bool isAuthenticating;
  final bool isLoadingData;
  final bool isImporting;
  final bool isExporting;
  final String? sessionToken;
  final String? statusMessage;
  final String? errorMessage;

  const AdminBackofficeState({
    required this.recordsByCollection,
    this.isAuthenticating = false,
    this.isLoadingData = false,
    this.isImporting = false,
    this.isExporting = false,
    this.sessionToken,
    this.statusMessage,
    this.errorMessage,
  });

  factory AdminBackofficeState.initial() {
    return AdminBackofficeState(
      recordsByCollection: {
        for (final definition in adminCollectionDefinitions)
          definition.name: [],
      },
    );
  }

  AdminBackofficeState copyWith({
    AdminCollectionRecords? recordsByCollection,
    bool? isAuthenticating,
    bool? isLoadingData,
    bool? isImporting,
    bool? isExporting,
    String? sessionToken,
    bool clearSessionToken = false,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AdminBackofficeState(
      recordsByCollection: recordsByCollection ?? this.recordsByCollection,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isLoadingData: isLoadingData ?? this.isLoadingData,
      isImporting: isImporting ?? this.isImporting,
      isExporting: isExporting ?? this.isExporting,
      sessionToken: clearSessionToken
          ? null
          : (sessionToken ?? this.sessionToken),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class AdminBackofficeController extends Notifier<AdminBackofficeState> {
  @override
  AdminBackofficeState build() => AdminBackofficeState.initial();

  Future<void> authenticate({
    required String baseUrl,
    required String tokenInput,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isAuthenticating: true,
      clearErrorMessage: true,
      clearStatusMessage: true,
    );

    try {
      final resolvedToken = tokenInput.isNotEmpty
          ? tokenInput
          : await ref.read(authenticateAdminSuperuserProvider)(
              baseUrl: baseUrl,
              email: email,
              password: password,
            );

      state = state.copyWith(
        sessionToken: resolvedToken,
        isAuthenticating: false,
        statusMessage: 'Session admin connectée.',
      );

      await refreshCollections(baseUrl: baseUrl, authToken: resolvedToken);
    } catch (error) {
      state = state.copyWith(isAuthenticating: false, errorMessage: '$error');
    }
  }

  Future<void> refreshCollections({
    required String baseUrl,
    required String authToken,
    String? successMessage,
  }) async {
    state = state.copyWith(isLoadingData: true, clearErrorMessage: true);

    try {
      final refreshed = await ref.read(loadAdminCollectionsProvider)(
        baseUrl: baseUrl,
        authToken: authToken,
        collections: [
          for (final definition in adminCollectionDefinitions)
            AdminCollectionLoadRequest(
              name: definition.name,
              sort: definition.sort,
            ),
        ],
      );

      state = state.copyWith(
        isLoadingData: false,
        recordsByCollection: refreshed,
        statusMessage:
            successMessage ?? 'Collections synchronisées avec PocketBase.',
      );
    } catch (error) {
      state = state.copyWith(isLoadingData: false, errorMessage: '$error');
    }
  }

  Future<void> importCatalog({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) async {
    state = state.copyWith(
      isImporting: true,
      clearErrorMessage: true,
      clearStatusMessage: true,
    );

    try {
      final report = await ref.read(importCatalogCsvProvider)(
        baseUrl: baseUrl,
        authToken: authToken,
        csvContent: csvContent,
      );

      await refreshCollections(
        baseUrl: baseUrl,
        authToken: authToken,
        successMessage: report.toSummary(
          labelForCollection: (collection) =>
              adminCollectionDefinitionsByName[collection]?.label ?? collection,
        ),
      );
      _invalidate(invalidationsForCatalogImportReport(report));
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
    } finally {
      state = state.copyWith(isImporting: false);
    }
  }

  Future<CatalogExportResult?> exportCatalog({
    required String baseUrl,
    required String authToken,
  }) async {
    state = state.copyWith(
      isExporting: true,
      clearErrorMessage: true,
      clearStatusMessage: true,
    );

    try {
      final result = await ref.read(exportCatalogCsvProvider)(
        baseUrl: baseUrl,
        authToken: authToken,
      );

      state = state.copyWith(statusMessage: result.toSummary());
      return result;
    } catch (error) {
      state = state.copyWith(errorMessage: '$error');
      return null;
    } finally {
      state = state.copyWith(isExporting: false);
    }
  }

  Future<void> saveRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String label,
    required Map<String, dynamic> data,
    String? recordId,
    String? mediaSource,
    String? mimeType,
    String fallbackFilename = 'media',
  }) async {
    state = state.copyWith(isLoadingData: true, clearErrorMessage: true);

    if (collection == 'products') {
      data['searchIndex'] = buildProductSearchIndex(data);
    }

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: collection,
        data: data,
        recordId: recordId,
        mediaSource: mediaSource,
        mimeType: mimeType,
        fallbackFilename: fallbackFilename,
      );

      await refreshCollections(
        baseUrl: baseUrl,
        authToken: authToken,
        successMessage:
            '$label: ${recordId == null ? 'création' : 'mise à jour'} effectuée.',
      );
      _invalidate(
        invalidationsForAdminSave(
          collection: collection,
          data: data,
          recordId: recordId,
        ),
      );
    } catch (error) {
      state = state.copyWith(isLoadingData: false, errorMessage: '$error');
    }
  }

  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required String label,
  }) async {
    state = state.copyWith(isLoadingData: true, clearErrorMessage: true);

    try {
      await ref.read(deleteAdminRecordProvider)(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: collection,
        recordId: recordId,
      );

      await refreshCollections(
        baseUrl: baseUrl,
        authToken: authToken,
        successMessage: '$label: suppression effectuée.',
      );
      _invalidate(
        invalidationsForAdminDelete(collection: collection, recordId: recordId),
      );
    } catch (error) {
      state = state.copyWith(isLoadingData: false, errorMessage: '$error');
    }
  }

  Future<void> rebuildSearchIndexes({
    required String baseUrl,
    required String authToken,
  }) async {
    state = state.copyWith(
      isLoadingData: true,
      clearErrorMessage: true,
      clearStatusMessage: true,
    );

    try {
      final repository = ref.read(adminBackofficeRepositoryProvider);
      int updatedCount = 0;
      int totalCount = 0;
      int page = 1;
      const perPage = 200;

      while (true) {
        final records = await repository.listRecords(
          baseUrl: baseUrl,
          authToken: authToken,
          collection: 'products',
          sort: 'code',
          perPage: perPage,
          page: page,
        );

        if (records.isEmpty) break;
        totalCount += records.length;

        for (final record in records) {
          final newIndex = buildProductSearchIndex(record);
          final currentIndex = record['searchIndex'] as String? ?? '';
          if (newIndex != currentIndex) {
            await repository.updateRecord(
              baseUrl: baseUrl,
              authToken: authToken,
              collection: 'products',
              recordId: record['id'] as String,
              data: {'searchIndex': newIndex},
            );
            updatedCount++;
          }
        }

        state = state.copyWith(
          statusMessage:
              'Index de recherche: $totalCount produits traités, $updatedCount mis à jour...',
        );

        if (records.length < perPage) break;
        page++;
      }

      state = state.copyWith(
        isLoadingData: false,
        statusMessage:
            'Index de recherche recalculé: $totalCount produits traités, $updatedCount mis à jour.',
      );
      _invalidate(const [AllSearchResultsInvalidation()]);
    } catch (error) {
      state = state.copyWith(isLoadingData: false, errorMessage: '$error');
    }
  }

  void showStatus(String message) {
    state = state.copyWith(statusMessage: message, clearErrorMessage: true);
  }

  void showError(String message) {
    state = state.copyWith(errorMessage: message, clearStatusMessage: true);
  }

  void clearSession() {
    state = state.copyWith(
      clearSessionToken: true,
      statusMessage: 'Session admin effacée.',
    );
  }

  void _invalidate(Iterable<CatalogInvalidationTarget> targets) {
    ref.read(catalogInvalidatorProvider).apply(ref, targets);
  }
}

final adminBackofficeControllerProvider =
    NotifierProvider<AdminBackofficeController, AdminBackofficeState>(
      AdminBackofficeController.new,
    );
