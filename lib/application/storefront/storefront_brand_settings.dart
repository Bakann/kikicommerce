import 'storefront_navigation_settings.dart';
import 'storefront_theme.dart';

const defaultStorefrontBrandTitle = "Kiki's Co";
const defaultStorefrontBrandHref = '/';
const storefrontSettingsCollection = 'storefront_settings';
const storefrontBrandSettingsKey = 'brand';

class StorefrontBrandSettings {
  final String? id;
  final String title;
  final String href;
  final bool replaceMobileLogoWithThemeSwitcher;

  const StorefrontBrandSettings({
    this.id,
    required this.title,
    required this.href,
    this.replaceMobileLogoWithThemeSwitcher = false,
  });

  static const fallback = StorefrontBrandSettings(
    title: defaultStorefrontBrandTitle,
    href: defaultStorefrontBrandHref,
  );

  factory StorefrontBrandSettings.fromJson(Map<String, dynamic> json) {
    final title = (json['brandTitle'] as String? ?? '').trim();
    final href = (json['brandHref'] as String? ?? '').trim();
    return StorefrontBrandSettings(
      id: (json['id'] as String?)?.trim(),
      title: title.isEmpty ? defaultStorefrontBrandTitle : title,
      href: href.isEmpty ? defaultStorefrontBrandHref : href,
      replaceMobileLogoWithThemeSwitcher:
          json['replaceMobileLogoWithThemeSwitcher'] as bool? ?? false,
    );
  }

  StorefrontBrandSettings copyWith({
    String? id,
    String? title,
    String? href,
    bool? replaceMobileLogoWithThemeSwitcher,
  }) {
    return StorefrontBrandSettings(
      id: id ?? this.id,
      title: title ?? this.title,
      href: href ?? this.href,
      replaceMobileLogoWithThemeSwitcher:
          replaceMobileLogoWithThemeSwitcher ??
          this.replaceMobileLogoWithThemeSwitcher,
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'key': storefrontBrandSettingsKey,
      'brandTitle': title.trim(),
      'brandHref': normalizedHref(href),
      'replaceMobileLogoWithThemeSwitcher': replaceMobileLogoWithThemeSwitcher,
    };
  }

  static String normalizedHref(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? defaultStorefrontBrandHref : trimmed;
  }
}

abstract interface class StorefrontSettingsRepository {
  Future<StorefrontBrandSettings> getBrandSettings();

  Future<StorefrontNavigationSettings> getNavigationSettings();

  Future<StorefrontActiveTheme> getActiveTheme();

  /// Persists the active theme to PocketBase. Requires an admin token.
  /// Creates the settings record if missing, otherwise updates in place.
  Future<void> saveActiveTheme({
    required String authToken,
    required StorefrontTheme theme,
    String? existingRecordId,
  });
}
