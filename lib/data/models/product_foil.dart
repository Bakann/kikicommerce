import 'dart:convert';

import '../../core/utils/media_url_builder.dart';

/// One `product_foils` record: the holo-overlay ingredients saved by the
/// Foil studio for a product — a grayscale relief texture ("foil"), an
/// alpha stencil ("mask") and the effect preset. A 2.5D record also carries
/// a pixel-aligned WebP copy of its source and the generated runtime layers.
class ProductFoil {
  final String id;
  final String collectionId;
  final String productId;
  final String? foilFilename;
  final String? maskFilename;
  final String? productImageFilename;
  final String? subjectMaskFilename;
  final String? backgroundCleanFilename;
  final String? rimFilename;
  final String? depthMapFilename;

  /// URL of the product image the foil was generated from. The overlay only
  /// applies to that exact media (foil and mask are pixel-aligned to it).
  final String sourceImage;
  final Map<String, dynamic> preset;
  final ProductFoilDepthMesh? depthMesh;
  final List<ProductFoilParticleSeed> particles;
  final String updated;

  const ProductFoil({
    required this.id,
    required this.collectionId,
    required this.productId,
    required this.foilFilename,
    required this.maskFilename,
    required this.productImageFilename,
    required this.subjectMaskFilename,
    required this.backgroundCleanFilename,
    required this.rimFilename,
    required this.depthMapFilename,
    required this.sourceImage,
    required this.preset,
    required this.depthMesh,
    required this.particles,
    required this.updated,
  });

  factory ProductFoil.fromJson(Map<String, dynamic> json) {
    final rawPreset = json['preset'];
    return ProductFoil(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'product_foils',
      productId: json['product_id'] as String? ?? '',
      foilFilename: _emptyToNull(json['foil'] as String?),
      maskFilename: _emptyToNull(json['mask'] as String?),
      productImageFilename: _emptyToNull(json['product_image'] as String?),
      subjectMaskFilename: _emptyToNull(json['subject_mask'] as String?),
      backgroundCleanFilename: _emptyToNull(
        json['background_clean'] as String?,
      ),
      rimFilename: _emptyToNull(json['rim'] as String?),
      depthMapFilename: _emptyToNull(json['depth_map'] as String?),
      sourceImage: json['source_image'] as String? ?? '',
      preset: rawPreset is Map<String, dynamic>
          ? rawPreset
          : const <String, dynamic>{},
      depthMesh: ProductFoilDepthMesh.tryParse(json['depth_mesh']),
      particles: ProductFoilParticleSeed.parseList(json['particles']),
      updated: json['updated'] as String? ?? '',
    );
  }

  static String? _emptyToNull(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  String? get foilUrl => _fileUrl(foilFilename);

  String? get maskUrl => _fileUrl(maskFilename);

  String? get productImageUrl => _fileUrl(productImageFilename);

  String? get subjectMaskUrl => _fileUrl(subjectMaskFilename);

  String? get backgroundCleanUrl => _fileUrl(backgroundCleanFilename);

  String? get rimUrl => _fileUrl(rimFilename);

  String? get depthMapUrl => _fileUrl(depthMapFilename);

  String? _fileUrl(String? filename) {
    if (filename == null) return null;
    return MediaUrlBuilder.fileUrl(
      collectionId: collectionId,
      recordId: id,
      filename: filename,
      version: updated,
    );
  }

  /// Global effect strength chosen in the studio (1 = nominal).
  double get intensity => (preset['intensity'] as num?)?.toDouble() ?? 1.0;

  bool get parallaxEnabled => preset['parallax'] == true;

  bool get volumeEnabled => parallaxEnabled && preset['volume'] == true;

  bool get particlesEnabled => preset['particles'] == true;

  /// The two-plane renderer needs a source image plus the three generated
  /// layers. Depth and particles are optional enhancements.
  bool get hasParallaxBundle =>
      parallaxEnabled &&
      (productImageUrl != null || sourceImage.isNotEmpty) &&
      subjectMaskUrl != null &&
      backgroundCleanUrl != null &&
      rimUrl != null;

  bool get hasVolumeBundle =>
      hasParallaxBundle && volumeEnabled && depthMesh != null;

  bool get hasParticleBundle => particlesEnabled && particles.isNotEmpty;

  /// Whether the foil was generated from the media with PocketBase id
  /// [mediaId] (its record id appears in the source image URL).
  bool matchesMediaId(String mediaId) =>
      mediaId.isNotEmpty && sourceImage.contains(mediaId);
}

/// Signed, boundary-pinned Depth Anything grid over the full source image.
class ProductFoilDepthMesh {
  const ProductFoilDepthMesh({
    required this.columns,
    required this.rows,
    required this.values,
    this.model,
  });

  final int columns;
  final int rows;
  final List<double> values;
  final String? model;

  static ProductFoilDepthMesh? tryParse(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      final columns = (decoded['columns'] as num).toInt();
      final rows = (decoded['rows'] as num).toInt();
      final rawValues = decoded['values'];
      if (columns < 2 || rows < 2 || rawValues is! List) return null;
      if (rawValues.length != columns * rows || rawValues.length > 10000) {
        return null;
      }
      final values = <double>[
        for (final value in rawValues)
          (value as num).toDouble().clamp(-1.0, 1.0).toDouble(),
      ];
      return ProductFoilDepthMesh(
        columns: columns,
        rows: rows,
        values: List.unmodifiable(values),
        model: decoded['model'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  double sample(double x, double y) {
    final gx = x.clamp(0.0, 1.0).toDouble() * (columns - 1);
    final gy = y.clamp(0.0, 1.0).toDouble() * (rows - 1);
    final x0 = gx.floor();
    final y0 = gy.floor();
    final x1 = (x0 + 1).clamp(0, columns - 1);
    final y1 = (y0 + 1).clamp(0, rows - 1);
    final tx = gx - x0;
    final ty = gy - y0;
    final top = _at(x0, y0) * (1 - tx) + _at(x1, y0) * tx;
    final bottom = _at(x0, y1) * (1 - tx) + _at(x1, y1) * tx;
    return top * (1 - ty) + bottom * ty;
  }

  double _at(int x, int y) => values[y * columns + x];
}

class ProductFoilParticleSeed {
  const ProductFoilParticleSeed({
    required this.x,
    required this.y,
    required this.brightness,
  });

  final double x;
  final double y;
  final double brightness;

  static List<ProductFoilParticleSeed> parseList(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return const [];
      return List.unmodifiable([
        for (final value in decoded.take(600))
          if (value is List && value.length >= 3)
            ProductFoilParticleSeed(
              x: (value[0] as num).toDouble().clamp(0.0, 1.0).toDouble(),
              y: (value[1] as num).toDouble().clamp(0.0, 1.0).toDouble(),
              brightness: (value[2] as num)
                  .toDouble()
                  .clamp(0.0, 1.0)
                  .toDouble(),
            ),
      ]);
    } catch (_) {
      return const [];
    }
  }
}
