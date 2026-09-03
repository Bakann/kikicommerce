import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/admin/admin_media.dart';

class MediaLibraryQuery {
  final String apiBaseUrl;
  final String mediaBaseUrl;
  final String authToken;
  final String searchQuery;
  final int perPage;
  final bool deferUntilSearch;
  final int minSearchLength;

  const MediaLibraryQuery({
    required this.authToken,
    required this.apiBaseUrl,
    required this.mediaBaseUrl,
    this.searchQuery = '',
    this.perPage = 60,
    this.deferUntilSearch = false,
    this.minSearchLength = 2,
  });

  String get normalizedSearchQuery => searchQuery.trim();

  bool get shouldDefer =>
      deferUntilSearch && normalizedSearchQuery.length < minSearchLength;

  @override
  bool operator ==(Object other) {
    return other is MediaLibraryQuery &&
        other.apiBaseUrl == apiBaseUrl &&
        other.mediaBaseUrl == mediaBaseUrl &&
        other.authToken == authToken &&
        other.normalizedSearchQuery == normalizedSearchQuery &&
        other.perPage == perPage &&
        other.deferUntilSearch == deferUntilSearch &&
        other.minSearchLength == minSearchLength;
  }

  @override
  int get hashCode => Object.hash(
    apiBaseUrl,
    mediaBaseUrl,
    authToken,
    normalizedSearchQuery,
    perPage,
    deferUntilSearch,
    minSearchLength,
  );
}

class MediaLibraryState {
  final List<AdminMedia> items;
  final int page;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isUploading;
  final bool isDeferred;
  final String? actionError;

  const MediaLibraryState({
    required this.items,
    required this.page,
    required this.hasMore,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isUploading = false,
    this.isDeferred = false,
    this.actionError,
  });

  const MediaLibraryState.empty()
    : items = const [],
      page = 1,
      hasMore = false,
      isRefreshing = false,
      isLoadingMore = false,
      isUploading = false,
      isDeferred = false,
      actionError = null;

  const MediaLibraryState.deferred()
    : items = const [],
      page = 1,
      hasMore = false,
      isRefreshing = false,
      isLoadingMore = false,
      isUploading = false,
      isDeferred = true,
      actionError = null;

  MediaLibraryState copyWith({
    List<AdminMedia>? items,
    int? page,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isUploading,
    bool? isDeferred,
    String? actionError,
    bool clearActionError = false,
  }) {
    return MediaLibraryState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isUploading: isUploading ?? this.isUploading,
      isDeferred: isDeferred ?? this.isDeferred,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}

final mediaLibraryProvider = AsyncNotifierProvider.autoDispose
    .family<MediaLibraryController, MediaLibraryState, MediaLibraryQuery>(
      MediaLibraryController.new,
    );

class MediaLibraryController extends AsyncNotifier<MediaLibraryState> {
  final MediaLibraryQuery _query;

  MediaLibraryController(this._query);

  @override
  Future<MediaLibraryState> build() async {
    if (_query.shouldDefer) {
      return const MediaLibraryState.deferred();
    }

    final items = await _loadPage(1);
    return MediaLibraryState(
      items: items,
      page: 1,
      hasMore: items.length >= _query.perPage,
    );
  }

  Future<void> refresh() async {
    if (_query.shouldDefer) {
      state = const AsyncValue.data(MediaLibraryState.deferred());
      return;
    }

    final previous = state.value;
    if (previous == null) {
      state = const AsyncValue.loading();
    } else {
      state = AsyncValue.data(
        previous.copyWith(isRefreshing: true, clearActionError: true),
      );
    }

    try {
      final items = await _loadPage(1);
      state = AsyncValue.data(
        MediaLibraryState(
          items: items,
          page: 1,
          hasMore: items.length >= _query.perPage,
        ),
      );
    } catch (error, stackTrace) {
      if (previous == null) {
        state = AsyncValue.error(error, stackTrace);
        return;
      }

      state = AsyncValue.data(
        previous.copyWith(isRefreshing: false, actionError: '$error'),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncValue.data(
      current.copyWith(isLoadingMore: true, clearActionError: true),
    );

    final nextPage = current.page + 1;
    try {
      final items = await _loadPage(nextPage);
      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...items],
          page: nextPage,
          hasMore: items.length >= _query.perPage,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      state = AsyncValue.data(
        current.copyWith(isLoadingMore: false, actionError: '$error'),
      );
    }
  }

  Future<AdminMedia?> uploadFile({
    required Uint8List fileBytes,
    required String filename,
  }) async {
    final current = state.value ?? const MediaLibraryState.empty();
    state = AsyncValue.data(
      current.copyWith(
        isUploading: true,
        isDeferred: false,
        clearActionError: true,
      ),
    );

    try {
      final optimized = ref
          .read(replaceMediaAssetProvider)
          .optimize(fileBytes: fileBytes, filename: filename);
      final record = await ref
          .read(adminBackofficeRepositoryProvider)
          .uploadMediaFromBytes(
            baseUrl: _query.apiBaseUrl,
            authToken: _query.authToken,
            fileBytes: optimized.fileBytes,
            filename: optimized.filename,
            mimeType: optimized.mimeType,
          );
      final media = AdminMedia.fromJson(record, baseUrl: _query.mediaBaseUrl);

      final latest = state.value ?? current;
      state = AsyncValue.data(
        latest.copyWith(
          items: [media, ...latest.items],
          hasMore: latest.hasMore,
          isUploading: false,
          isDeferred: false,
        ),
      );
      return media;
    } catch (error) {
      final latest = state.value ?? current;
      state = AsyncValue.data(
        latest.copyWith(
          isUploading: false,
          isDeferred: false,
          actionError: '$error',
        ),
      );
      return null;
    }
  }

  Future<List<AdminMedia>> _loadPage(int page) async {
    final records = await ref
        .read(adminBackofficeRepositoryProvider)
        .listRecords(
          baseUrl: _query.apiBaseUrl,
          authToken: _query.authToken,
          collection: 'medias',
          sort: '-updated',
          perPage: _query.perPage,
          page: page,
          filter: _buildFilter(_query.normalizedSearchQuery),
        );

    return records
        .map(
          (record) => AdminMedia.fromJson(record, baseUrl: _query.mediaBaseUrl),
        )
        .where((media) => media.file.isNotEmpty && media.isActive)
        .toList(growable: false);
  }

  String? _buildFilter(String query) {
    if (query.isEmpty) {
      return null;
    }

    final escaped = query.replaceAll("'", "\\'");
    return "title ~ '$escaped' || altText ~ '$escaped' || code ~ '$escaped'";
  }
}
