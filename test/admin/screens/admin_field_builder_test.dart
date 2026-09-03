import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/admin/admin_collection_schema.dart';
import 'package:kiki_commerce/admin/screens/admin_field_builder.dart';

void main() {
  group('validateAdminScalarField', () {
    const textField = AdminFieldDefinition(
      name: 'name',
      label: 'Nom',
      type: AdminFieldType.text,
      required: true,
    );
    const optionalText = AdminFieldDefinition(
      name: 'ean',
      label: 'EAN',
      type: AdminFieldType.text,
    );
    const integerField = AdminFieldDefinition(
      name: 'age',
      label: 'Âge',
      type: AdminFieldType.integer,
    );
    const decimalField = AdminFieldDefinition(
      name: 'price',
      label: 'Prix',
      type: AdminFieldType.decimal,
    );
    const dateTimeField = AdminFieldDefinition(
      name: 'onlineDate',
      label: 'Date en ligne',
      type: AdminFieldType.dateTime,
    );

    test('required empty returns the Champ requis error', () {
      expect(validateAdminScalarField(textField, ''), 'Champ requis');
      expect(validateAdminScalarField(textField, '   '), 'Champ requis');
    });

    test('optional empty returns null', () {
      expect(validateAdminScalarField(optionalText, ''), isNull);
      expect(validateAdminScalarField(optionalText, null), isNull);
    });

    test('integer parses or flags Entier attendu', () {
      expect(validateAdminScalarField(integerField, '42'), isNull);
      expect(validateAdminScalarField(integerField, 'abc'), 'Entier attendu');
    });

    test('decimal tolerates comma and rejects garbage', () {
      expect(validateAdminScalarField(decimalField, '3,14'), isNull);
      expect(validateAdminScalarField(decimalField, '3.14'), isNull);
      expect(validateAdminScalarField(decimalField, 'nope'), 'Nombre attendu');
    });

    test('dateTime accepts ISO dates and rejects garbage', () {
      expect(validateAdminScalarField(dateTimeField, '2026-06-07'), isNull);
      expect(
        validateAdminScalarField(dateTimeField, '2026-06-07T12:30:00Z'),
        isNull,
      );
      expect(
        validateAdminScalarField(dateTimeField, 'demain'),
        'Date ou date-heure ISO attendue',
      );
    });
  });

  group('AdminBooleanField', () {
    testWidgets('emits onChanged when toggled', (tester) async {
      const field = AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      );
      bool captured = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminBooleanField(
              field: field,
              value: true,
              onChanged: (value) => captured = value,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(captured, isFalse);
    });
  });

  group('AdminSelectField', () {
    testWidgets('picks an option from the dropdown', (tester) async {
      const field = AdminFieldDefinition(
        name: 'gender',
        label: 'Genre',
        type: AdminFieldType.select,
        options: ['male', 'female', 'unisex'],
      );
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSelectField(
              field: field,
              value: null,
              onChanged: (value) => captured = value,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('female').last);
      await tester.pumpAndSettle();
      expect(captured, 'female');
    });
  });

  group('AdminMultiRelationField', () {
    testWidgets('toggles selection via FilterChip', (tester) async {
      const field = AdminFieldDefinition(
        name: 'medias',
        label: 'Médias',
        type: AdminFieldType.relationMultiple,
        relationCollection: 'medias',
      );
      final toggles = <(String, bool)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMultiRelationField(
              field: field,
              selected: const {'m1'},
              records: const [
                {'id': 'm1', 'code': 'alpha'},
                {'id': 'm2', 'code': 'beta'},
              ],
              onToggle: (id, value) => toggles.add((id, value)),
            ),
          ),
        ),
      );

      final betaChip = find.widgetWithText(FilterChip, 'beta');
      expect(betaChip, findsOneWidget);
      await tester.tap(betaChip);
      await tester.pumpAndSettle();
      expect(toggles, [('m2', true)]);
    });

    testWidgets('shows placeholder when no options', (tester) async {
      const field = AdminFieldDefinition(
        name: 'medias',
        label: 'Médias',
        type: AdminFieldType.relationMultiple,
        relationCollection: 'medias',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminMultiRelationField(
              field: field,
              selected: const {},
              records: const [],
              onToggle: (_, _) {},
            ),
          ),
        ),
      );
      expect(find.text('Aucune option disponible'), findsOneWidget);
    });
  });
}
