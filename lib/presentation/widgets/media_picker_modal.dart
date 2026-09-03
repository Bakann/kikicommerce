import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/admin/admin_media.dart';
import '../../core/constants.dart';
import '../providers/media_library_provider.dart';
import 'kiki_image.dart';

class MediaPickerInitialSelection {
  final String mediaId;
  final String previewUrl;
  final String? title;
  final String? altText;

  const MediaPickerInitialSelection({
    required this.mediaId,
    required this.previewUrl,
    this.title,
    this.altText,
  });

  bool get hasPreview => previewUrl.trim().isNotEmpty;
}

class MediaPickerResult {
  final String mediaId;
  final AdminMedia media;

  const MediaPickerResult({required this.mediaId, required this.media});
}

class _MediaPickerTitle extends StatelessWidget {
  const _MediaPickerTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Choisir une image',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class MediaPickerModal extends ConsumerStatefulWidget {
  final String authToken;
  final String? currentMediaId;
  final MediaPickerInitialSelection? initialSelection;

  const MediaPickerModal({
    super.key,
    required this.authToken,
    this.currentMediaId,
    this.initialSelection,
  });

  static Future<MediaPickerResult?> show(
    BuildContext context, {
    required String authToken,
    String? currentMediaId,
    MediaPickerInitialSelection? initialSelection,
  }) {
    return showDialog<MediaPickerResult>(
      context: context,
      builder: (_) => MediaPickerModal(
        authToken: authToken,
        currentMediaId: currentMediaId,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  ConsumerState<MediaPickerModal> createState() => _MediaPickerModalState();
}

class _MediaPickerModalState extends ConsumerState<MediaPickerModal> {
  static const int _perPage = 8;
  static const int _minSearchLength = 2;
  static const String _listThumbSize = '120x120';
  static const String _previewThumbSize = '600x600';
  static const Duration _searchDebounce = Duration(milliseconds: 300);

  String? _selectedMediaId;
  AdminMedia? _selectedMedia;
  String _searchQuery = '';
  bool _showRecent = false;
  Timer? _searchTimer;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMediaId = null;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    _selectedMediaId = null;
    _selectedMedia = null;
  }

  void _selectMedia(AdminMedia media) {
    setState(() {
      _selectedMediaId = media.id;
      _selectedMedia = media;
    });
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
        _showRecent = false;
        _clearSelection();
      });
    });
  }

  void _showLatestMedia() {
    _searchTimer?.cancel();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _showRecent = true;
      _clearSelection();
    });
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final media = await ref
        .read(mediaLibraryProvider(_query).notifier)
        .uploadFile(fileBytes: file.bytes!, filename: file.name);
    if (!mounted || media == null) {
      return;
    }

    _selectMedia(media);
  }

  void _confirmSelection() {
    final media = _selectedMediaFrom(
      ref.read(mediaLibraryProvider(_query)).value?.items ?? const [],
    );
    if (media == null) return;
    Navigator.of(
      context,
    ).pop(MediaPickerResult(mediaId: media.id, media: media));
  }

  MediaLibraryQuery get _query => MediaLibraryQuery(
    authToken: widget.authToken,
    apiBaseUrl: ref.read(apiBaseUrlProvider),
    mediaBaseUrl: ref.read(mediaBaseUrlProvider),
    searchQuery: _searchQuery,
    perPage: _perPage,
    deferUntilSearch: !_showRecent,
    minSearchLength: _minSearchLength,
  );

  AdminMedia? _selectedMediaFrom(List<AdminMedia> items) {
    final selectedId = _selectedMediaId;
    if (selectedId == null) {
      return null;
    }

    final cached = _selectedMedia;
    if (cached != null && cached.id == selectedId) {
      return cached;
    }

    for (final media in items) {
      if (media.id == selectedId) {
        return media;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 900;
    final libraryAsync = ref.watch(mediaLibraryProvider(_query));
    final library = libraryAsync.value;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(library),
            const Divider(height: 1),
            Expanded(
              child: libraryAsync.when(
                data: (state) => _buildLibraryBody(state, isWide: isWide),
                loading: () => _buildLoadingBody(library, isWide: isWide),
                error: (error, _) => _buildError(
                  '$error',
                  onRetry: () =>
                      ref.read(mediaLibraryProvider(_query).notifier).refresh(),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(library),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MediaLibraryState? library) {
    final isUploading = library?.isUploading ?? false;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 620;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: isCompact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: _MediaPickerTitle()),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildSearchField()),
                    const SizedBox(width: 10),
                    _buildUploadButton(isUploading),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const _MediaPickerTitle(),
                const SizedBox(width: 16),
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _showLatestMedia,
                  child: const Text('Voir les derniers médias'),
                ),
                const SizedBox(width: 8),
                _buildUploadButton(isUploading),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                ),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          prefixIcon: const Icon(Icons.search, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD9DEE6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD9DEE6)),
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildUploadButton(bool isUploading) {
    return OutlinedButton.icon(
      onPressed: isUploading ? null : _uploadFile,
      icon: isUploading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_outlined, size: 18),
      label: const Text('Importer'),
    );
  }

  Widget _buildLoadingBody(MediaLibraryState? library, {required bool isWide}) {
    if (library != null) {
      return _buildLibraryBody(
        library.copyWith(isRefreshing: true),
        isWide: isWide,
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildLibraryBody(MediaLibraryState library, {required bool isWide}) {
    final selectedMedia = _selectedMediaFrom(library.items);
    final leadingContent = Column(
      children: [
        if (library.isRefreshing) const LinearProgressIndicator(minHeight: 2),
        if (library.actionError != null)
          _InlineMediaLibraryError(
            message: library.actionError!,
            onRetry: () =>
                ref.read(mediaLibraryProvider(_query).notifier).refresh(),
          ),
        if (_initialSelection case final initialSelection?)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _InitialMediaCard(selection: initialSelection),
          ),
        Expanded(child: _buildResults(library)),
      ],
    );

    if (!isWide) {
      return Column(
        children: [
          Expanded(child: leadingContent),
          if (selectedMedia != null) ...[
            const Divider(height: 1),
            SizedBox(height: 140, child: _buildPreview(selectedMedia)),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: leadingContent),
        const VerticalDivider(width: 1),
        SizedBox(width: 300, child: _buildPreview(selectedMedia)),
      ],
    );
  }

  MediaPickerInitialSelection? get _initialSelection {
    final initial = widget.initialSelection;
    if (initial != null && initial.hasPreview) {
      return initial;
    }
    return null;
  }

  Widget _buildResults(MediaLibraryState library) {
    if (library.isDeferred) {
      return _DeferredMediaSearch(
        minSearchLength: _minSearchLength,
        onShowLatest: _showLatestMedia,
      );
    }

    if (library.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_search_outlined,
                size: 34,
                color: Colors.grey.shade500,
              ),
              const SizedBox(height: 10),
              Text(
                _searchQuery.trim().isEmpty
                    ? 'Aucun média récent disponible.'
                    : 'Aucune image trouvée.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _showLatestMedia,
                child: const Text('Voir les derniers médias'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: library.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final media = library.items[index];
              final isSelected = media.id == _selectedMediaId;
              return _MediaListTile(
                media: media,
                thumbSize: _listThumbSize,
                isSelected: isSelected,
                onTap: () => _selectMedia(media),
                onDoubleTap: () {
                  _selectedMediaId = media.id;
                  _selectedMedia = media;
                  _confirmSelection();
                },
              );
            },
          ),
        ),
        if (library.hasMore)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: library.isLoadingMore
                ? const SizedBox(
                    height: 32,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: () => ref
                        .read(mediaLibraryProvider(_query).notifier)
                        .loadMore(),
                    child: const Text('Charger 8 de plus'),
                  ),
          ),
      ],
    );
  }

  Widget _buildPreview(AdminMedia? media) {
    if (media == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Sélectionnez un résultat\npour le prévisualiser.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final isWide = MediaQuery.sizeOf(context).width > 900;

    if (!isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: KikiImage(
                imageUrl: media.thumbUrl(size: _previewThumbSize),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildMetadata(media)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: KikiImage(
              imageUrl: media.thumbUrl(size: _previewThumbSize),
              width: double.infinity,
              height: 180,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetadata(media),
        ],
      ),
    );
  }

  Widget _buildMetadata(AdminMedia media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (media.title != null && media.title!.isNotEmpty)
          Text(
            media.title!,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (media.code != null &&
            media.code!.isNotEmpty &&
            media.code != media.title)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              media.code!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        if (media.altText != null && media.altText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Alt: ${media.altText!}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (media.mimeType != null && media.mimeType!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              media.mimeType!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
      ],
    );
  }

  Widget _buildError(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  Widget _buildActions(MediaLibraryState? library) {
    final selectedMedia = _selectedMediaFrom(library?.items ?? const []);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: selectedMedia == null ? null : _confirmSelection,
            style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
            child: const Text(
              'Sélectionner',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialMediaCard extends StatelessWidget {
  final MediaPickerInitialSelection selection;

  const _InitialMediaCard({required this.selection});

  @override
  Widget build(BuildContext context) {
    final subtitle = selection.title ?? selection.altText;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        border: Border.all(color: const Color(0xFFD9DEE6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: KikiImage(
              imageUrl: selection.previewUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Image actuelle',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeferredMediaSearch extends StatelessWidget {
  final int minSearchLength;
  final VoidCallback onShowLatest;

  const _DeferredMediaSearch({
    required this.minSearchLength,
    required this.onShowLatest,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_outlined, size: 34, color: Colors.grey.shade500),
            const SizedBox(height: 10),
            Text(
              'Tapez au moins $minSearchLength caractères pour rechercher une image.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onShowLatest,
              child: const Text('Voir les derniers médias'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMediaLibraryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineMediaLibraryError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _MediaListTile extends StatelessWidget {
  final AdminMedia media;
  final String thumbSize;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _MediaListTile({
    required this.media,
    required this.thumbSize,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = media.title ?? media.code ?? media.file;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? kNavyBlue : const Color(0xFFD9DEE6),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: KikiImage(
                    imageUrl: media.thumbUrl(size: thumbSize),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (media.altText != null && media.altText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            media.altText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (media.mimeType != null && media.mimeType!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            media.mimeType!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: kNavyBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 15,
                    ),
                  )
                else
                  const SizedBox(width: 24, height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
