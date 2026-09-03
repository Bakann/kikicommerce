import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/data/local/visitor_storefront_theme_store.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';

void main() {
  test(
    'effective theme falls back to server theme without local override',
    () async {
      final container = _container(
        store: _MemoryVisitorStorefrontThemeStore(),
        activeTheme: StorefrontTheme.nike,
      );
      addTearDown(container.dispose);

      await container.read(resolvedStorefrontThemeProvider.future);

      expect(
        container.read(effectiveStorefrontThemeAsyncProvider).value,
        StorefrontTheme.nike,
      );
    },
  );

  test('valid local override wins over server theme', () async {
    final container = _container(
      store: _MemoryVisitorStorefrontThemeStore(rawValue: 'nike'),
      activeTheme: StorefrontTheme.dior,
    );
    addTearDown(container.dispose);

    await container.read(resolvedStorefrontThemeProvider.future);

    expect(
      container.read(effectiveStorefrontThemeAsyncProvider).value,
      StorefrontTheme.nike,
    );
  });

  test('invalid local override is ignored', () async {
    final container = _container(
      store: _MemoryVisitorStorefrontThemeStore(rawValue: 'broken'),
      activeTheme: StorefrontTheme.nike,
    );
    addTearDown(container.dispose);

    await container.read(resolvedStorefrontThemeProvider.future);

    expect(
      container.read(effectiveStorefrontThemeAsyncProvider).value,
      StorefrontTheme.nike,
    );
  });

  test('admin preview wins over local override', () async {
    final container = _container(
      store: _MemoryVisitorStorefrontThemeStore(rawValue: 'nike'),
      activeTheme: StorefrontTheme.nike,
      editingTheme: StorefrontTheme.dior,
    );
    addTearDown(container.dispose);

    expect(
      container.read(effectiveStorefrontThemeAsyncProvider).value,
      StorefrontTheme.dior,
    );
  });

  test(
    'local loading keeps effective theme loading even if server is ready',
    () {
      final localRead = Completer<StorefrontTheme?>();
      final container = ProviderContainer(
        overrides: [
          visitorStorefrontThemeOverrideProvider.overrideWith(
            (ref) => localRead.future,
          ),
          activeStorefrontThemeProvider.overrideWith(
            (ref) async =>
                const StorefrontActiveTheme(theme: StorefrontTheme.nike),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(effectiveStorefrontThemeAsyncProvider).isLoading,
        true,
      );
    },
  );

  test(
    'clearOverride removes local value and returns to server theme',
    () async {
      final store = _MemoryVisitorStorefrontThemeStore(rawValue: 'nike');
      final container = _container(
        store: store,
        activeTheme: StorefrontTheme.dior,
      );
      addTearDown(container.dispose);

      await container.read(resolvedStorefrontThemeProvider.future);
      expect(
        container.read(effectiveStorefrontThemeAsyncProvider).value,
        StorefrontTheme.nike,
      );

      await store.clearOverride();
      container.invalidate(visitorStorefrontThemeOverrideProvider);
      await container.read(resolvedStorefrontThemeProvider.future);

      expect(
        container.read(effectiveStorefrontThemeAsyncProvider).value,
        StorefrontTheme.dior,
      );
    },
  );
}

ProviderContainer _container({
  required VisitorStorefrontThemeStore store,
  required StorefrontTheme activeTheme,
  StorefrontTheme? editingTheme,
}) {
  return ProviderContainer(
    overrides: [
      visitorStorefrontThemeStoreProvider.overrideWithValue(store),
      activeStorefrontThemeProvider.overrideWith(
        (ref) async => StorefrontActiveTheme(theme: activeTheme),
      ),
      if (editingTheme != null)
        editingStorefrontThemeProvider.overrideWith((ref) => editingTheme),
    ],
  );
}

class _MemoryVisitorStorefrontThemeStore
    implements VisitorStorefrontThemeStore {
  String? rawValue;

  _MemoryVisitorStorefrontThemeStore({this.rawValue});

  @override
  Future<StorefrontTheme?> readOverride() async {
    return StorefrontTheme.tryFromWireName(rawValue);
  }

  @override
  Future<void> writeOverride(StorefrontTheme theme) async {
    rawValue = theme.wireName;
  }

  @override
  Future<void> clearOverride() async {
    rawValue = null;
  }
}
