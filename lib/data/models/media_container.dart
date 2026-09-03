import 'media.dart';

class MediaContainer {
  final String id;
  final String collectionId;
  final String? code;
  final String? name;
  final List<String> mediaIds;
  final List<Media> medias;
  final bool isActive;

  MediaContainer({
    required this.id,
    required this.collectionId,
    this.code,
    this.name,
    this.mediaIds = const [],
    this.medias = const [],
    this.isActive = true,
  });

  factory MediaContainer.fromJson(
    Map<String, dynamic> json, {
    String? baseUrl,
  }) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    return MediaContainer(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      code: json['code'] as String?,
      name: json['name'] as String?,
      mediaIds:
          (json['medias'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      medias:
          (expand['medias'] as List<dynamic>?)
              ?.map(
                (e) =>
                    Media.fromJson(e as Map<String, dynamic>, baseUrl: baseUrl),
              )
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
