import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../application/navigation/navigation_editor_options.dart';

class NavigationEditorOptionsRequest {
  final String baseUrl;
  final String authToken;
  final DrawerNavigationItemData? initialItem;

  const NavigationEditorOptionsRequest({
    required this.authToken,
    required this.baseUrl,
    this.initialItem,
  });
}

final navigationEditorOptionsProvider = FutureProvider.autoDispose
    .family<NavigationEditorOptionsBundle, NavigationEditorOptionsRequest>((
      ref,
      request,
    ) {
      return ref.watch(loadNavigationEditorOptionsProvider)(
        baseUrl: request.baseUrl,
        authToken: request.authToken,
        initialItem: request.initialItem,
      );
    });
