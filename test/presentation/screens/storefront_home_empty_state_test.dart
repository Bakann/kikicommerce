import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/screens/storefront_home_page.dart';

import '../../support/l10n_harness.dart';

Future<void> _pumpHome(WidgetTester tester, {required bool editMode}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No default category -> the home page renders an empty state.
        defaultCategoryProvider.overrideWith((ref) => null),
        editModeProvider.overrideWith((ref) => editMode),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        home: const Scaffold(body: StorefrontHomePage()),
      ),
    ),
  );
}

void main() {
  testWidgets('public empty catalogue shows sober copy and no admin CTA', (
    tester,
  ) async {
    await _pumpHome(tester, editMode: false);
    await tester.pumpAndSettle();

    expect(find.text('Bientôt disponible'), findsOneWidget);
    // No technical/admin detail leaks to public visitors.
    expect(find.text('Importer des données'), findsNothing);
    expect(find.text('Ouvrir le backoffice'), findsNothing);
    expect(find.textContaining('PocketBase'), findsNothing);
  });

  testWidgets('edit mode surfaces the admin remediation CTA', (tester) async {
    await _pumpHome(tester, editMode: true);
    await tester.pumpAndSettle();

    expect(find.text('Aucune catégorie active'), findsOneWidget);
    expect(find.text('Importer des données'), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsNothing);
  });

  testWidgets('public unknown category shows the not-found copy, not empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A requested slug that resolves to no category.
          categoryBySlugProvider('missing').overrideWith((ref) => null),
          editModeProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(
            body: StorefrontHomePage(categorySlug: 'missing'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page indisponible'), findsOneWidget);
    expect(find.text('Bientôt disponible'), findsNothing);
    expect(find.text('Importer des données'), findsNothing);
  });
}
