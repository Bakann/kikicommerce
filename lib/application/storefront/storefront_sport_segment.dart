enum StorefrontSportSegment {
  homme('homme', 'Homme'),
  femme('femme', 'Femme'),
  enfant('enfant', 'Enfant');

  final String wireName;
  final String displayLabel;

  const StorefrontSportSegment(this.wireName, this.displayLabel);

  static const fallback = StorefrontSportSegment.homme;

  static StorefrontSportSegment? tryParse(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final segment in StorefrontSportSegment.values) {
      if (segment.wireName == normalized) return segment;
    }
    return null;
  }

  static StorefrontSportSegment parse(String? value) {
    return tryParse(value) ?? fallback;
  }

  /// The segment whose homepage CMS page should be used when this segment has
  /// no page of its own. `homme` is the root and has no fallback. Single source
  /// of truth for the homepage fallback chain (consumed by
  /// `homepageCmsForSegmentProvider`).
  StorefrontSportSegment? get homepageFallback => switch (this) {
    StorefrontSportSegment.homme => null,
    StorefrontSportSegment.femme => StorefrontSportSegment.homme,
    StorefrontSportSegment.enfant => StorefrontSportSegment.homme,
  };
}

String homepageCodeForSportSegment(StorefrontSportSegment segment) {
  return switch (segment) {
    StorefrontSportSegment.homme => 'homepage_nike',
    StorefrontSportSegment.femme => 'homepage_nike_femme',
    StorefrontSportSegment.enfant => 'homepage_nike_enfant',
  };
}
