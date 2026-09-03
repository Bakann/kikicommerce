import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/category_split_tabs_form.dart';

void main() {
  testWidgets('emits expansibleTitle while preserving items (no displayMode)', (
    tester,
  ) async {
    Map<String, dynamic>? emitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategorySplitTabsForm(
            initialConfig: const {
              'defaultActiveIndex': 0,
              'items': [
                {'label': 'Homme', 'href': '/sport/homme', 'segment': 'homme'},
              ],
            },
            onChanged: (config) => emitted = config,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Titre de l\'en-tête (déplié)'),
      'Parcourir',
    );
    await tester.pump();

    expect(emitted, isNotNull);
    expect(emitted!['expansibleTitle'], 'Parcourir');
    // The tabs/expansible choice is global now — never written per-section.
    expect(emitted!.containsKey('displayMode'), isFalse);
    final items = emitted!['items'] as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['label'], 'Homme');
  });
}
