class NarrativeChapterRecord {
  final String id;
  final String productId;
  final String mediaId;
  final int position;
  final String headline;
  final String? story;
  final String? ctaLabel;
  final String? ctaAction;
  final bool isActive;

  const NarrativeChapterRecord({
    required this.id,
    required this.productId,
    required this.mediaId,
    required this.position,
    required this.headline,
    this.story,
    this.ctaLabel,
    this.ctaAction,
    this.isActive = true,
  });

  factory NarrativeChapterRecord.fromJson(Map<String, dynamic> json) {
    return NarrativeChapterRecord(
      id: json['id'] as String,
      productId: json['product'] as String? ?? '',
      mediaId: json['media'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      headline: json['headline'] as String? ?? '',
      story: json['story'] as String?,
      ctaLabel: json['ctaLabel'] as String?,
      ctaAction: json['ctaAction'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
