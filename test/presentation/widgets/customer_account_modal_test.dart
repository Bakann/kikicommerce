import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/shared_app_bar.dart';

import '../../support/l10n_harness.dart';

void main() {
  void setMobileSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSurface(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('account icon opens anonymous account accordion modal', (
    tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(body: SharedPdpNavBar()),
        ),
      ),
    );

    await tester.tap(find.byIcon(CupertinoIcons.person).first);
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text("S'inscrire"), findsOneWidget);
    expect(find.text('Suivre votre commande'), findsOneWidget);

    await tester.tap(find.text('Suivre votre commande'));
    await tester.pumpAndSettle();

    expect(find.text('* E-mail'), findsOneWidget);
    expect(find.text('* Numéro de commande'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);

    await tester.tap(find.text("S'inscrire"));
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Ajouter des articles à\nvotre wishlist'), findsOneWidget);
    expect(find.text('* Numéro de commande'), findsNothing);
  });
}
