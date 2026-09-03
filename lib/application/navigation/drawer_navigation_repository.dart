import 'drawer_navigation_models.dart';

abstract interface class DrawerNavigationRepository {
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  });
}
