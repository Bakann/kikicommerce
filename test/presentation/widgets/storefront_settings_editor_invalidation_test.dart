import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/save_admin_record.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_brand_editor_dialog.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_navigation_editor_dialog.dart';

// Regression guard: editing brand/navigation settings must invalidate the
// matching FutureProvider so consumers refetch instead of showing the stale
// pre-save value. The save is deferred so the tests also lock the *ordering*:
// invalidation must happen only after the write resolves, not before — moving
// the invalidate ahead of the await would surface a rebuild while the save is
// still pending and fail the `builds == 1` check.
void main() {
  testWidgets('brand editor invalidates brand settings after save', (
    tester,
  ) async {
    var builds = 0;
    final save = _DeferredSaveAdminRecord();
    const seed = StorefrontBrandSettings(
      id: 'brand-1',
      title: 'Kiki',
      href: '/',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthTokenProvider.overrideWith((ref) => 'token'),
          saveAdminRecordProvider.overrideWithValue(save),
          storefrontBrandSettingsProvider.overrideWith((ref) async {
            builds++;
            return seed;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => StorefrontBrandEditorDialog.show(
                  context,
                  initialSettings: seed,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Keep the provider alive so the post-save invalidation actually re-runs
    // its builder (an unlistened provider would not rebuild eagerly).
    final sub = _containerOf(
      tester,
    ).listen(storefrontBrandSettingsProvider, (_, _) {});
    await tester.pump();
    expect(builds, 1, reason: 'provider should build once before save');

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();

    // The write is still in flight: invalidation must not have happened yet.
    expect(save.calls, 1);
    expect(builds, 1, reason: 'must not invalidate before the write resolves');

    save.completer.complete();
    await tester.pumpAndSettle();

    expect(builds, 2, reason: 'invalidate only after the write resolves');
    sub.close();
  });

  testWidgets('navigation editor invalidates navigation settings after save', (
    tester,
  ) async {
    var builds = 0;
    final save = _DeferredSaveAdminRecord();
    const seed = StorefrontNavigationSettings(
      id: 'nav-1',
      mobileMenuStyle: MobileMenuStyle.drawer,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthTokenProvider.overrideWith((ref) => 'token'),
          saveAdminRecordProvider.overrideWithValue(save),
          storefrontNavigationSettingsProvider.overrideWith((ref) async {
            builds++;
            return seed;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => StorefrontNavigationEditorDialog.show(
                  context,
                  initialSettings: seed,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sub = _containerOf(
      tester,
    ).listen(storefrontNavigationSettingsProvider, (_, _) {});
    await tester.pump();
    expect(builds, 1, reason: 'provider should build once before save');

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Enregistrer'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();

    expect(save.calls, 1);
    expect(builds, 1, reason: 'must not invalidate before the write resolves');

    save.completer.complete();
    await tester.pumpAndSettle();

    expect(builds, 2, reason: 'invalidate only after the write resolves');
    sub.close();
  });
}

ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

class _DeferredSaveAdminRecord extends SaveAdminRecord {
  _DeferredSaveAdminRecord() : super(_UnusedAdminRepo());

  int calls = 0;
  final completer = Completer<void>();

  @override
  Future<void> call({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
    String? recordId,
    String? mediaSource,
    String? mimeType,
    String fallbackFilename = 'media',
  }) {
    calls++;
    return completer.future;
  }
}

// Never invoked: _RecordingSaveAdminRecord overrides call(), so the wrapped
// repository is unused. noSuchMethod throws to surface any unexpected use.
class _UnusedAdminRepo implements AdminBackofficeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
