import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/admin/admin_media.dart' as admin_media;
import '../../application/admin/media_crop_data.dart';
import '../../application/admin/optimize_media_upload.dart';
import '../../core/constants.dart';
import '../../core/utils/media_upload_guidance.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../screens/product_detail_layout_spec.dart';
import 'kiki_image.dart';

class PhotoPublishResult {
  final OptimizedMediaUpload optimized;
  final String mediaId;
  final String authToken;
  final Uint8List? originalFileBytes;
  final String? originalFilename;
  final MediaCropData? cropData;

  const PhotoPublishResult({
    required this.optimized,
    required this.mediaId,
    required this.authToken,
    required this.originalFileBytes,
    required this.originalFilename,
    required this.cropData,
  });
}

class PhotoUploadDialog extends ConsumerStatefulWidget {
  final CatalogMedia currentMedia;
  final String currentMediaId;
  final String authToken;

  const PhotoUploadDialog({
    super.key,
    required this.currentMedia,
    required this.currentMediaId,
    required this.authToken,
  });

  static Future<PhotoPublishResult?> show(
    BuildContext context, {
    required CatalogMedia currentMedia,
    required String currentMediaId,
    required String authToken,
  }) {
    return showDialog<PhotoPublishResult>(
      context: context,
      builder: (_) => PhotoUploadDialog(
        currentMedia: currentMedia,
        currentMediaId: currentMediaId,
        authToken: authToken,
      ),
    );
  }

  @override
  ConsumerState<PhotoUploadDialog> createState() => _PhotoUploadDialogState();
}

class _PhotoUploadDialogState extends ConsumerState<PhotoUploadDialog> {
  static const String _pocketBaseGridThumbSize = '100x100';
  static const double _zoomStep = 0.2;
  static const double _maxZoomScale = 5;
  static const double _zoomScaleEpsilon = 0.01;
  static const _cropPresets = <_CropPreset>[
    _CropPreset(
      key: 'pdp',
      label: 'PDP',
      aspectRatio: productDetailMobileHeroAspectRatio,
    ),
    _CropPreset(key: 'listing', label: 'Listing', aspectRatio: 3 / 4),
    _CropPreset(key: 'square', label: 'Carré', aspectRatio: 1),
  ];

  late final CropController _cropController;
  late final MediaCropData? _storedCropData;

  Uint8List? _sourceBytes;
  String? _sourceFilename;
  _SourceImageDimensions? _sourceImageDimensions;
  bool _loadingSource = true;
  bool _uploading = false;
  String? _error;
  int _cropperVersion = 0;
  bool _useStoredCrop = true;
  MediaCropData? _latestCropData;
  double? _currentScale;
  double? _minimumScale;
  bool _showPocketBaseGrid = false;
  bool _loadingPocketBaseMedia = false;
  String? _pocketBaseMediaError;
  List<_PocketBaseMediaOption> _pocketBaseMediaOptions = const [];
  String? _selectedPocketBaseMediaId;
  late _CropPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _cropController = CropController();
    _storedCropData = _readStoredCropData(widget.currentMedia);
    _selectedPreset =
        _presetForKey(_storedCropData?.presetKey) ?? _cropPresets.first;
    _latestCropData = _storedCropData;
    _selectedPocketBaseMediaId = widget.currentMedia.id;
    unawaited(_loadInitialSource());
  }

  Future<void> _loadInitialSource() async {
    final sourceUrl =
        widget.currentMedia.originalUrl ?? widget.currentMedia.url;
    final sourceFilename = _filenameFromUrl(sourceUrl);

    try {
      final source = await _fetchSourceFromUrl(
        sourceUrl,
        sourceFilename: sourceFilename,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _applySourceData(
          source,
          keepStoredCrop: true,
          selectedPocketBaseMediaId: widget.currentMedia.id,
        );
        _loadingSource = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _loadingSource = false;
      });
    }
  }

  Future<_LoadedSourceData> _fetchSourceFromUrl(
    String sourceUrl, {
    String? sourceFilename,
  }) async {
    final bytes = await ref
        .read(adminMediaRepositoryProvider)
        .fetchBytes(sourceUrl);
    final filename = sourceFilename ?? _filenameFromUrl(sourceUrl);
    final dimensions = await _readImageDimensionsAsync(bytes, filename);
    return _LoadedSourceData(
      bytes: bytes,
      filename: filename,
      dimensions: dimensions,
    );
  }

  void _applySourceData(
    _LoadedSourceData source, {
    bool keepStoredCrop = false,
    bool bumpCropperVersion = false,
    String? selectedPocketBaseMediaId,
  }) {
    _sourceBytes = source.bytes;
    _sourceFilename = source.filename;
    _sourceImageDimensions = source.dimensions;
    _error = null;
    _loadingSource = false;
    _useStoredCrop = keepStoredCrop;
    _latestCropData = keepStoredCrop ? _storedCropData : null;
    _currentScale = null;
    _minimumScale = null;
    _selectedPocketBaseMediaId = selectedPocketBaseMediaId;
    if (bumpCropperVersion) {
      _cropperVersion += 1;
    }
  }

  Future<void> _pickReplacementImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() {
        _error = 'Le fichier sélectionné ne contient pas de données lisibles.';
      });
      return;
    }
    final fileBytes = file.bytes!;
    final fileName = file.name;
    final dimensions = await _readImageDimensionsAsync(fileBytes, fileName);
    if (!mounted) return;

    setState(() {
      _applySourceData(
        _LoadedSourceData(
          bytes: fileBytes,
          filename: fileName,
          dimensions: dimensions,
        ),
        bumpCropperVersion: true,
      );
    });
  }

  Future<void> _togglePocketBaseGrid() async {
    if (_showPocketBaseGrid) {
      setState(() {
        _showPocketBaseGrid = false;
      });
      return;
    }

    setState(() {
      _showPocketBaseGrid = true;
    });

    if (_pocketBaseMediaOptions.isNotEmpty || _loadingPocketBaseMedia) {
      return;
    }

    await _loadPocketBaseMediaOptions();
  }

  Future<void> _loadPocketBaseMediaOptions() async {
    setState(() {
      _loadingPocketBaseMedia = true;
      _pocketBaseMediaError = null;
    });

    try {
      final records = await ref
          .read(adminBackofficeRepositoryProvider)
          .listRecords(
            baseUrl: ref.read(apiBaseUrlProvider),
            authToken: widget.authToken,
            collection: 'medias',
            sort: '-updated',
            perPage: 120,
          );

      final options = records
          .map(
            (record) => admin_media.AdminMedia.fromJson(
              record,
              baseUrl: ref.read(mediaBaseUrlProvider),
            ),
          )
          .where((media) => media.file.isNotEmpty && media.isActive)
          .map(
            (media) => _PocketBaseMediaOption(
              id: media.id,
              label: media.title ?? media.code ?? media.file,
              thumbUrl: media.thumbUrl(size: _pocketBaseGridThumbSize),
              sourceUrl: media.originalFileUrl ?? media.fileUrl,
              filename: media.originalFile?.isNotEmpty == true
                  ? media.originalFile!
                  : media.file,
            ),
          )
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _pocketBaseMediaOptions = options;
        _loadingPocketBaseMedia = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingPocketBaseMedia = false;
        _pocketBaseMediaError = '$error';
      });
    }
  }

  Future<void> _selectPocketBaseMedia(_PocketBaseMediaOption option) async {
    if (_loadingSource || _uploading) {
      return;
    }

    setState(() {
      _loadingSource = true;
      _error = null;
      _pocketBaseMediaError = null;
    });

    try {
      final source = await _fetchSourceFromUrl(
        option.sourceUrl,
        sourceFilename: option.filename,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _applySourceData(
          source,
          bumpCropperVersion: true,
          selectedPocketBaseMediaId: option.id,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingSource = false;
        _error = '$error';
      });
    }
  }

  Future<void> _upload() async {
    final sourceBytes = _sourceBytes;
    final sourceFilename = _sourceFilename;
    if (sourceBytes == null || sourceFilename == null) {
      setState(() {
        _error = 'Aucune image source n’est disponible.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final optimized = ref
          .read(replaceMediaAssetProvider)
          .cropAndOptimize(
            sourceBytes: sourceBytes,
            filename: sourceFilename,
            cropData: _effectiveCropData(),
          );

      final result = PhotoPublishResult(
        optimized: await optimized,
        mediaId: widget.currentMediaId,
        authToken: widget.authToken,
        originalFileBytes: sourceBytes,
        originalFilename: sourceFilename,
        cropData: _latestCropData,
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      setState(() {
        _error = '$error';
        _uploading = false;
      });
    }
  }

  void _handleCropped(CropResult result) {
    return;
  }

  void _handleCropMoved(Rect _, Rect imageBasedRect) {
    final dimensions = _sourceImageDimensions;
    if (dimensions == null || dimensions.width <= 0 || dimensions.height <= 0) {
      return;
    }

    _latestCropData = MediaCropData(
      presetKey: _selectedPreset.key,
      x: (imageBasedRect.left / dimensions.width).clamp(0.0, 1.0),
      y: (imageBasedRect.top / dimensions.height).clamp(0.0, 1.0),
      width: (imageBasedRect.width / dimensions.width).clamp(0.0, 1.0),
      height: (imageBasedRect.height / dimensions.height).clamp(0.0, 1.0),
    );
  }

  MediaCropData _effectiveCropData() {
    final latestCropData = _latestCropData;
    if (latestCropData != null && _cropMatchesSelectedPreset(latestCropData)) {
      return latestCropData;
    }

    final dimensions = _sourceImageDimensions;
    if (dimensions == null || dimensions.width <= 0 || dimensions.height <= 0) {
      return MediaCropData(
        presetKey: _selectedPreset.key,
        x: 0,
        y: 0,
        width: 1,
        height: 1,
      );
    }

    final imageAspect = dimensions.width / dimensions.height;
    final presetAspect = _selectedPreset.aspectRatio;
    final cropWidth = imageAspect > presetAspect
        ? presetAspect / imageAspect
        : 1.0;
    final cropHeight = imageAspect > presetAspect
        ? 1.0
        : imageAspect / presetAspect;

    return MediaCropData(
      presetKey: _selectedPreset.key,
      x: (1 - cropWidth) / 2,
      y: (1 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
    );
  }

  void _selectPreset(_CropPreset preset) {
    if (_selectedPreset == preset) {
      return;
    }
    setState(() {
      _selectedPreset = preset;
      _useStoredCrop = false;
      _latestCropData = null;
    });
    _cropController.reset(aspectRatio: preset.aspectRatio);
  }

  void _resetEditor() {
    setState(() {
      _useStoredCrop = false;
      _latestCropData = null;
      _currentScale = null;
      _minimumScale = null;
    });
    _cropController.reset(aspectRatio: _selectedPreset.aspectRatio);
  }

  void _stepZoom(double delta) {
    if (_loadingSource ||
        _uploading ||
        _sourceBytes == null ||
        (delta < 0 && !_canZoomOut) ||
        (delta > 0 && !_canZoomIn)) {
      return;
    }
    _cropController.addScale(delta);
  }

  void _handleScaleChanged(double scale, double minScale) {
    if (!mounted) {
      return;
    }

    final normalizedScale = scale < minScale ? minScale : scale;
    final scaleChanged =
        _currentScale == null ||
        (normalizedScale - _currentScale!).abs() > _zoomScaleEpsilon;
    final minChanged =
        _minimumScale == null ||
        (minScale - _minimumScale!).abs() > _zoomScaleEpsilon;
    if (!scaleChanged && !minChanged) {
      return;
    }

    setState(() {
      _currentScale = normalizedScale;
      _minimumScale = minScale;
    });
  }

  bool get _canZoomOut {
    final currentScale = _currentScale;
    final minimumScale = _minimumScale;
    if (currentScale == null || minimumScale == null) {
      return false;
    }
    return currentScale - minimumScale > _zoomScaleEpsilon;
  }

  bool get _canZoomIn {
    final currentScale = _currentScale;
    if (currentScale == null) {
      return false;
    }
    return _maxZoomScale - currentScale > _zoomScaleEpsilon;
  }

  String? get _zoomStatusText {
    final currentScale = _currentScale;
    if (currentScale == null) {
      return null;
    }
    if (!_canZoomOut) {
      return 'Zoom minimum atteint';
    }
    if (!_canZoomIn) {
      return 'Zoom maximum atteint';
    }
    return 'Zoom ${(currentScale * 100 / _maxZoomScale).round()}% de la plage';
  }

  InitialRectBuilder _initialRectBuilder() {
    final storedCrop = _storedCropData;
    final image = _sourceImageDimensions;
    if (_useStoredCrop &&
        storedCrop != null &&
        image != null &&
        _cropMatchesSelectedPreset(storedCrop)) {
      final left = (storedCrop.x * image.width).clamp(
        0.0,
        image.width.toDouble(),
      );
      final top = (storedCrop.y * image.height).clamp(
        0.0,
        image.height.toDouble(),
      );
      final width = (storedCrop.width * image.width).clamp(
        1.0,
        image.width.toDouble(),
      );
      final height = (storedCrop.height * image.height).clamp(
        1.0,
        image.height.toDouble(),
      );

      return InitialRectBuilder.withArea(
        Rect.fromLTWH(left, top, width, height),
      );
    }

    return InitialRectBuilder.withSizeAndRatio(
      size: 1,
      aspectRatio: _selectedPreset.aspectRatio,
    );
  }

  bool _cropMatchesSelectedPreset(MediaCropData cropData) {
    if (cropData.presetKey != _selectedPreset.key) {
      return false;
    }

    final dimensions = _sourceImageDimensions;
    if (dimensions == null || dimensions.width <= 0 || dimensions.height <= 0) {
      return true;
    }

    final cropAspect =
        (cropData.width * dimensions.width) /
        (cropData.height * dimensions.height);
    return (cropAspect - _selectedPreset.aspectRatio).abs() < 0.02;
  }

  @override
  Widget build(BuildContext context) {
    final sourceBytes = _sourceBytes;
    final sourceFilename = _sourceFilename;
    final advisory = advisoryForImageUpload(
      sourceBytes?.lengthInBytes ?? mediaUploadRecommendedMaxBytes,
    );
    final advisoryColor = switch (advisory.level) {
      MediaUploadAdvisoryLevel.info => const Color(0xFFE8F1FF),
      MediaUploadAdvisoryLevel.warning => const Color(0xFFFFF4DB),
      MediaUploadAdvisoryLevel.error => const Color(0xFFFDE7E9),
    };
    final advisoryTextColor = switch (advisory.level) {
      MediaUploadAdvisoryLevel.info => const Color(0xFF1F4B99),
      MediaUploadAdvisoryLevel.warning => const Color(0xFF8A5A00),
      MediaUploadAdvisoryLevel.error => const Color(0xFF9D1B1E),
    };

    return AlertDialog(
      title: const Text('Publier l\'image'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final preset in _cropPresets)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: preset == _selectedPreset,
                      onSelected: _loadingSource || _uploading
                          ? null
                          : (_) => _selectPreset(preset),
                    ),
                  OutlinedButton.icon(
                    onPressed: _loadingSource || _uploading || !_canZoomOut
                        ? null
                        : () => _stepZoom(-_zoomStep),
                    icon: const Icon(Icons.remove),
                    label: const Text('Zoom -'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadingSource || _uploading || !_canZoomIn
                        ? null
                        : () => _stepZoom(_zoomStep),
                    icon: const Icon(Icons.add),
                    label: const Text('Zoom +'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadingSource || _uploading
                        ? null
                        : _pickReplacementImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choisir une autre image'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _togglePocketBaseGrid,
                    icon: const Icon(Icons.collections_outlined),
                    label: Text(
                      _showPocketBaseGrid
                          ? 'Masquer PocketBase'
                          : 'Choisir depuis PocketBase',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadingSource || _uploading
                        ? null
                        : _resetEditor,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Déplace l’image dans le cadre et zoome selon le besoin. Le pinch peut rester capricieux sur iOS web; les boutons Zoom - / Zoom + servent de fallback fiable. Si un crop existait, il est restauré automatiquement.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_zoomStatusText != null) ...[
                const SizedBox(height: 6),
                Text(
                  _zoomStatusText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF526170),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_showPocketBaseGrid) ...[
                const SizedBox(height: 14),
                _PocketBaseMediaGrid(
                  mediaOptions: _pocketBaseMediaOptions,
                  selectedMediaId: _selectedPocketBaseMediaId,
                  loading: _loadingPocketBaseMedia,
                  error: _pocketBaseMediaError,
                  onRetry: _loadingPocketBaseMedia
                      ? null
                      : _loadPocketBaseMediaOptions,
                  onSelect: _loadingSource || _uploading
                      ? null
                      : _selectPocketBaseMedia,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                height: 430,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD9DEE6)),
                ),
                clipBehavior: Clip.hardEdge,
                child: _loadingSource
                    ? const Center(child: CircularProgressIndicator())
                    : sourceBytes == null
                    ? const Center(
                        child: Text(
                          'Aucune image source disponible pour le crop.',
                        ),
                      )
                    : Crop(
                        key: ValueKey(
                          '${_cropperVersion}_${sourceBytes.length}',
                        ),
                        image: sourceBytes,
                        controller: _cropController,
                        onCropped: _handleCropped,
                        onMoved: _handleCropMoved,
                        aspectRatio: _selectedPreset.aspectRatio,
                        initialRectBuilder: _initialRectBuilder(),
                        precomputedImageSize: _sourceImageDimensions != null
                            ? Size(
                                _sourceImageDimensions!.width.toDouble(),
                                _sourceImageDimensions!.height.toDouble(),
                              )
                            : null,
                        interactive: true,
                        fixCropRect: true,
                        willUpdateScale: (newScale) =>
                            newScale >= 1 && newScale <= _maxZoomScale,
                        onScaleChanged: _handleScaleChanged,
                        radius: 20,
                        scrollZoomSensitivity: 0.08,
                        baseColor: const Color(0xFFF2F4F7),
                        maskColor: Colors.black.withValues(alpha: 0.26),
                        cornerDotBuilder: (size, edgeAlignment) =>
                            const SizedBox.shrink(),
                        filterQuality: FilterQuality.high,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                sourceFilename == null
                    ? 'Source introuvable'
                    : 'Fichier: $sourceFilename · ${formatBytesForHumans(sourceBytes?.lengthInBytes ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: advisoryColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: advisoryTextColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advisory.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: advisoryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      advisory.message,
                      style: TextStyle(fontSize: 13, color: advisoryTextColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Après le crop, l’app optimise encore le rendu pour le storefront, avec un côté long cible autour de ${mediaUploadRecommendedLongEdge}px.',
                      style: TextStyle(fontSize: 13, color: advisoryTextColor),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _uploading || _loadingSource || sourceBytes == null
              ? null
              : _upload,
          style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
          child: _uploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Publier', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  MediaCropData? _readStoredCropData(CatalogMedia media) {
    if (media.cropPreset == null ||
        media.cropX == null ||
        media.cropY == null ||
        media.cropWidth == null ||
        media.cropHeight == null) {
      return null;
    }

    return MediaCropData(
      presetKey: media.cropPreset!,
      x: media.cropX!,
      y: media.cropY!,
      width: media.cropWidth!,
      height: media.cropHeight!,
    );
  }

  _CropPreset? _presetForKey(String? key) {
    for (final preset in _cropPresets) {
      if (preset.key == key) {
        return preset;
      }
    }
    return null;
  }

  String _filenameFromUrl(String url) {
    final uri = Uri.parse(url);
    final segment = uri.pathSegments.isEmpty
        ? 'media.jpg'
        : uri.pathSegments.last;
    return segment.isEmpty ? 'media.jpg' : segment;
  }
}

/// Read image dimensions natively using the browser/Flutter engine's async C++ decoder
/// This prevents any javascript single-thread blocking (jank).
Future<_SourceImageDimensions?> _readImageDimensionsAsync(
  Uint8List bytes,
  String filename,
) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  final image = await completer.future;

  final width = image.width;
  final height = image.height;
  image.dispose(); // Critical to avoid memory leaks with ui.Image

  if (width <= 0 || height <= 0) return null;
  return _SourceImageDimensions(width: width, height: height);
}

class _SourceImageDimensions {
  final int width;
  final int height;

  const _SourceImageDimensions({required this.width, required this.height});
}

class _LoadedSourceData {
  final Uint8List bytes;
  final String filename;
  final _SourceImageDimensions? dimensions;

  const _LoadedSourceData({
    required this.bytes,
    required this.filename,
    required this.dimensions,
  });
}

class _CropPreset {
  final String key;
  final String label;
  final double aspectRatio;

  const _CropPreset({
    required this.key,
    required this.label,
    required this.aspectRatio,
  });
}

class _PocketBaseMediaOption {
  final String id;
  final String label;
  final String thumbUrl;
  final String sourceUrl;
  final String filename;

  const _PocketBaseMediaOption({
    required this.id,
    required this.label,
    required this.thumbUrl,
    required this.sourceUrl,
    required this.filename,
  });
}

class _PocketBaseMediaGrid extends StatelessWidget {
  final List<_PocketBaseMediaOption> mediaOptions;
  final String? selectedMediaId;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<_PocketBaseMediaOption>? onSelect;

  const _PocketBaseMediaGrid({
    required this.mediaOptions,
    required this.selectedMediaId,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Médiathèque PocketBase',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Sélectionnez une image existante. La grille charge uniquement les plus petits thumbnails; le fichier source complet n’est téléchargé qu’au clic.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              height: 192,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            SizedBox(
              height: 192,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          else if (mediaOptions.isEmpty)
            const SizedBox(
              height: 192,
              child: Center(child: Text('Aucune image PocketBase disponible.')),
            )
          else
            SizedBox(
              height: 232,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: mediaOptions.length,
                scrollCacheExtent: const ScrollCacheExtent.pixels(300),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  final option = mediaOptions[index];
                  return _PocketBaseMediaTile(
                    option: option,
                    isSelected: option.id == selectedMediaId,
                    onTap: onSelect == null ? null : () => onSelect!(option),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PocketBaseMediaTile extends StatelessWidget {
  final _PocketBaseMediaOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PocketBaseMediaTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: option.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? kNavyBlue : const Color(0xFFD9DEE6),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: KikiImage(
                    imageUrl: option.thumbUrl,
                    width: 200, // Small preview grid
                    height: 200,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kNavyBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
