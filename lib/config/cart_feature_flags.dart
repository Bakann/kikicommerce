class CartFeatureFlags {
  static const bool useCartAddEndpoint = bool.fromEnvironment(
    'USE_CART_ADD_ENDPOINT',
    defaultValue: true,
  );
}
