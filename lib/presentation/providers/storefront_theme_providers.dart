import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/app_providers.dart';
import '../../application/storefront/storefront_theme.dart';
import '../../data/local/visitor_storefront_theme_store.dart';

/// Resolved + persisted theme from `storefront_settings.active_theme`.
final activeStorefrontThemeProvider = FutureProvider<StorefrontActiveTheme>((
  ref,
) {
  return ref.watch(storefrontSettingsRepositoryProvider).getActiveTheme();
});

/// Local override used in edit mode. When non-null the storefront previews
/// this theme without persisting. Cleared on "Annuler" or after "Appliquer".
final editingStorefrontThemeProvider = StateProvider<StorefrontTheme?>(
  (ref) => null,
);

final visitorStorefrontThemeStoreProvider =
    Provider<VisitorStorefrontThemeStore>(
      (ref) => SharedPreferencesVisitorStorefrontThemeStore(),
    );

/// Persists the visitor's theme choice and refreshes the resolution chain.
/// Single source of truth for committing a theme switch (tap switcher and
/// interactive swipe both call this so the override/invalidation order can't
/// diverge).
Future<void> writeVisitorStorefrontThemeOverride(
  WidgetRef ref,
  StorefrontTheme theme,
) async {
  final previewTheme = ref.read(editingStorefrontThemeProvider);
  await ref.read(visitorStorefrontThemeStoreProvider).writeOverride(theme);
  if (previewTheme != null) {
    ref.read(editingStorefrontThemeProvider.notifier).state = theme;
  }
  ref.invalidate(visitorStorefrontThemeOverrideProvider);
  ref.invalidate(resolvedStorefrontThemeProvider);
}

final visitorStorefrontThemeOverrideProvider = FutureProvider<StorefrontTheme?>(
  (ref) {
    return ref.watch(visitorStorefrontThemeStoreProvider).readOverride();
  },
);

final resolvedStorefrontThemeProvider = FutureProvider<StorefrontTheme>((
  ref,
) async {
  final editing = ref.watch(editingStorefrontThemeProvider);
  if (editing != null) return editing;

  StorefrontTheme? visitorOverride;
  try {
    visitorOverride = await ref.watch(
      visitorStorefrontThemeOverrideProvider.future,
    );
  } catch (_) {
    visitorOverride = null;
  }
  if (visitorOverride != null) return visitorOverride;

  return (await ref.watch(activeStorefrontThemeProvider.future)).theme;
});

/// Final theme state used by storefront chrome: admin preview first, then the
/// visitor's local choice, then the persisted active theme. While the visitor
/// choice is loading, callers render a neutral shell instead of briefly showing
/// the server theme before switching to the local theme.
final effectiveStorefrontThemeAsyncProvider =
    Provider<AsyncValue<StorefrontTheme>>((ref) {
      final editing = ref.watch(editingStorefrontThemeProvider);
      if (editing != null) return AsyncValue.data(editing);

      final visitor = ref.watch(visitorStorefrontThemeOverrideProvider);
      return visitor.when(
        data: (localTheme) {
          if (localTheme != null) return AsyncValue.data(localTheme);
          return ref
              .watch(activeStorefrontThemeProvider)
              .whenData((active) => active.theme);
        },
        error: (_, _) {
          return ref
              .watch(activeStorefrontThemeProvider)
              .whenData((active) => active.theme);
        },
        loading: () => const AsyncValue.loading(),
      );
    });
