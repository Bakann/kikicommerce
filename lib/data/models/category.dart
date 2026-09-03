class Category {
  final String id;
  final String collectionId;
  final String code;
  final String name;
  final String? description;
  final String? slug;
  final bool isActive;
  final bool isHidden;
  final int position;
  final String? parentId;

  Category({
    required this.id,
    required this.collectionId,
    required this.code,
    required this.name,
    this.description,
    this.slug,
    this.isActive = true,
    this.isHidden = false,
    this.position = 0,
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      slug: json['slug'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isHidden: json['isHidden'] as bool? ?? false,
      position: (json['position'] as num?)?.toInt() ?? 0,
      parentId: json['parent'] as String?,
    );
  }
}
