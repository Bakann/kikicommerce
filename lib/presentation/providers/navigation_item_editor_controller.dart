import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/navigation/save_navigation_item.dart';
import 'catalog_invalidator_provider.dart';

class NavigationItemEditorSaveRequest {
  final String baseUrl;
  final String authToken;
  final SaveNavigationItemInput input;

  const NavigationItemEditorSaveRequest({
    required this.authToken,
    required this.input,
    required this.baseUrl,
  });
}

final navigationItemEditorControllerProvider =
    NotifierProvider.autoDispose<
      NavigationItemEditorController,
      AsyncValue<void>
    >(NavigationItemEditorController.new);

class NavigationItemEditorController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> save(NavigationItemEditorSaveRequest request) async {
    state = const AsyncLoading();

    try {
      await ref.read(saveNavigationItemProvider)(
        baseUrl: request.baseUrl,
        authToken: request.authToken,
        input: request.input,
      );

      ref
          .read(catalogInvalidatorProvider)
          .apply(
            ref,
            invalidationsForAdminSave(
              collection: 'navigation_items',
              data: const {},
              recordId: request.input.recordId,
            ),
          );

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
