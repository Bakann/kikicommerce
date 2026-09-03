import 'media.dart';
import 'media_container.dart';

class Product {
  final String id;
  final String collectionId;
  final String collectionName;
  final String code;
  final String name;
  final String? slug;
  final String? summary;
  final String? description;
  final String? ean;
  final String? gender;
  final String? productType;
  final String? brand;
  final bool isActive;
  final DateTime? onlineDate;
  final DateTime? offlineDate;

  // Relation IDs (raw)
  final String? pictureId;
  final String? thumbnailId;
  final List<String> galleryImageIds;

  // Expanded relations
  final Media? picture;
  final Media? thumbnail;
  final List<MediaContainer> galleryImages;

  Product({
    required this.id,
    required this.collectionId,
    required this.collectionName,
    required this.code,
    required this.name,
    this.slug,
    this.summary,
    this.description,
    this.ean,
    this.gender,
    this.productType,
    this.brand,
    this.isActive = true,
    this.onlineDate,
    this.offlineDate,
    this.pictureId,
    this.thumbnailId,
    this.galleryImageIds = const [],
    this.picture,
    this.thumbnail,
    this.galleryImages = const [],
  });

  Product copyWith({List<MediaContainer>? galleryImages}) {
    return Product(
      id: id,
      collectionId: collectionId,
      collectionName: collectionName,
      code: code,
      name: name,
      slug: slug,
      summary: summary,
      description: description,
      ean: ean,
      gender: gender,
      productType: productType,
      brand: brand,
      isActive: isActive,
      onlineDate: onlineDate,
      offlineDate: offlineDate,
      pictureId: pictureId,
      thumbnailId: thumbnailId,
      galleryImageIds: galleryImageIds,
      picture: picture,
      thumbnail: thumbnail,
      galleryImages: galleryImages ?? this.galleryImages,
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? expand,
    String? baseUrl,
  }) {
    expand ??= json['expand'] as Map<String, dynamic>? ?? {};

    return Product(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      collectionName: json['collectionName'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      summary: json['summary'] as String?,
      description: json['description'] as String?,
      ean: json['ean'] as String?,
      gender: json['gender'] as String?,
      productType: json['productType'] as String?,
      brand: json['brand'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      onlineDate: json['onlineDate'] != null
          ? DateTime.tryParse(json['onlineDate'] as String)
          : null,
      offlineDate: json['offlineDate'] != null
          ? DateTime.tryParse(json['offlineDate'] as String)
          : null,
      pictureId: json['picture'] as String?,
      thumbnailId: json['thumbnail'] as String?,
      galleryImageIds:
          (json['galleryImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      picture: expand['picture'] != null
          ? Media.fromJson(
              expand['picture'] as Map<String, dynamic>,
              baseUrl: baseUrl,
            )
          : null,
      thumbnail: expand['thumbnail'] != null
          ? Media.fromJson(
              expand['thumbnail'] as Map<String, dynamic>,
              baseUrl: baseUrl,
            )
          : null,
      galleryImages:
          (expand['galleryImages'] as List<dynamic>?)
              ?.map(
                (e) => MediaContainer.fromJson(
                  e as Map<String, dynamic>,
                  baseUrl: baseUrl,
                ),
              )
              .toList() ??
          [],
    );
  }
}
