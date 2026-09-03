const storefrontNavigationSettingsKey = 'navigation';

enum MobileMenuStyle {
  drawer('drawer'),
  fullscreenReveal('fullscreenReveal');

  final String value;

  const MobileMenuStyle(this.value);

  static MobileMenuStyle fromValue(String? value) {
    final normalized = value?.trim();
    for (final style in MobileMenuStyle.values) {
      if (style.value == normalized) {
        return style;
      }
    }
    return MobileMenuStyle.drawer;
  }
}

/// Global design of the `category_split_tabs` section across the sport
/// homepages. Stored here (not per-section) so the choice persists across the
/// segment landings (Homme/Femme/Enfant).
enum CategorySplitDisplayMode {
  tabs('tabs'),
  expansible('expansible');

  final String value;

  const CategorySplitDisplayMode(this.value);

  static CategorySplitDisplayMode? tryParse(String? value) {
    final normalized = value?.trim();
    for (final mode in CategorySplitDisplayMode.values) {
      if (mode.value == normalized) {
        return mode;
      }
    }
    return null;
  }

  static CategorySplitDisplayMode fromValue(String? value) {
    return tryParse(value) ?? CategorySplitDisplayMode.tabs;
  }
}

class StorefrontNavigationSettings {
  final String? id;
  final MobileMenuStyle mobileMenuStyle;
  final CategorySplitDisplayMode categorySplitDisplayMode;
  final bool hasCategorySplitDisplayMode;

  const StorefrontNavigationSettings({
    this.id,
    required this.mobileMenuStyle,
    this.categorySplitDisplayMode = CategorySplitDisplayMode.tabs,
    this.hasCategorySplitDisplayMode = true,
  });

  static const fallback = StorefrontNavigationSettings(
    mobileMenuStyle: MobileMenuStyle.drawer,
    hasCategorySplitDisplayMode: false,
  );

  factory StorefrontNavigationSettings.fromJson(Map<String, dynamic> json) {
    final parsedSplitMode = CategorySplitDisplayMode.tryParse(
      json['categorySplitDisplayMode'] as String?,
    );
    return StorefrontNavigationSettings(
      id: (json['id'] as String?)?.trim(),
      mobileMenuStyle: MobileMenuStyle.fromValue(
        json['mobileMenuStyle'] as String?,
      ),
      categorySplitDisplayMode:
          parsedSplitMode ?? CategorySplitDisplayMode.tabs,
      hasCategorySplitDisplayMode: parsedSplitMode != null,
    );
  }

  StorefrontNavigationSettings copyWith({
    String? id,
    MobileMenuStyle? mobileMenuStyle,
    CategorySplitDisplayMode? categorySplitDisplayMode,
    bool? hasCategorySplitDisplayMode,
  }) {
    return StorefrontNavigationSettings(
      id: id ?? this.id,
      mobileMenuStyle: mobileMenuStyle ?? this.mobileMenuStyle,
      categorySplitDisplayMode:
          categorySplitDisplayMode ?? this.categorySplitDisplayMode,
      hasCategorySplitDisplayMode:
          hasCategorySplitDisplayMode ??
          (categorySplitDisplayMode != null
              ? true
              : this.hasCategorySplitDisplayMode),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'key': storefrontNavigationSettingsKey,
      'mobileMenuStyle': mobileMenuStyle.value,
      'categorySplitDisplayMode': categorySplitDisplayMode.value,
    };
  }
}
