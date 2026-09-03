import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/content_locale_provider.dart';

import '../../support/l10n_harness.dart';

Widget _appWithLocale(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    home: const ContentLocaleSync(child: SizedBox.shrink()),
  );
}

void main() {
  test('defaults to the French fallback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(contentLocaleProvider), 'fr');
  });

  test('seeded controller returns the seed (first-frame launch locale)', () {
    final container = ProviderContainer(
      overrides: [
        contentLocaleProvider.overrideWith(
          () => ContentLocaleController(seeded: 'en'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(contentLocaleProvider), 'en');
  });

  testWidgets(
    'ContentLocaleSync mirrors the resolved locale into the provider',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _appWithLocale(const Locale('en')),
        ),
      );
      await tester.pump(); // run the post-frame sync

      expect(container.read(contentLocaleProvider), 'en');
    },
  );

  testWidgets('ContentLocaleSync follows a language switch (en -> fr)', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _appWithLocale(const Locale('en')),
      ),
    );
    await tester.pump();
    expect(container.read(contentLocaleProvider), 'en');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _appWithLocale(const Locale('fr')),
      ),
    );
    await tester.pump();
    expect(container.read(contentLocaleProvider), 'fr');
  });
}
