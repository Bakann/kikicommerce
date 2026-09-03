import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cart_feature_flags.dart';

class PdpLoadingQuickAddFlags {
  static const bool enabled = bool.fromEnvironment(
    'PDP_LOADING_QUICK_ADD',
    defaultValue: true,
  );
}

final pdpLoadingQuickAddEnabledProvider = Provider<bool>((ref) {
  return PdpLoadingQuickAddFlags.enabled;
});

final pdpLoadingQuickAddServerValidationProvider = Provider<bool>((ref) {
  return CartFeatureFlags.useCartAddEndpoint;
});
