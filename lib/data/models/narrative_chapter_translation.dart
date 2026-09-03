/// A per-locale row from `narrative_chapter_translations`. Holds only the
/// visitor-facing strings of a PDP narrative chapter; the base record keeps the
/// media, position, ctaAction and flags. Blank overrides normalize to `null` so
/// the mapper falls back to the base (default-locale) value.
class NarrativeChapterTranslation {
  final String chapterId;
  final String locale;
  final String headline;
  final String? story;
  final String? ctaLabel;

  const NarrativeChapterTranslation({
    required this.chapterId,
    required this.locale,
    required this.headline,
    this.story,
    this.ctaLabel,
  });

  factory NarrativeChapterTranslation.fromJson(Map<String, dynamic> json) {
    return NarrativeChapterTranslation(
      chapterId: json['chapter'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      headline: (json['headline'] as String?) ?? '',
      story: _nullIfBlank(json['story'] as String?),
      ctaLabel: _nullIfBlank(json['ctaLabel'] as String?),
    );
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  return value.trim().isEmpty ? null : value;
}
