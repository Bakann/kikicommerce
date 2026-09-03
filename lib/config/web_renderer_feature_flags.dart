class WebRendererFeatureFlags {
  /// Enables runtime fragment shaders in the Sport bottom navbar.
  ///
  /// The production-safe default uses standard Material Home and Search icons,
  /// so mounting the navbar never compiles a `FragmentProgram` or displays the
  /// custom optical treatments.
  /// Re-enable explicitly with `--dart-define=ENABLE_NAVBAR_SHADERS=true`.
  static const bool enableNavbarShaders = bool.fromEnvironment(
    'ENABLE_NAVBAR_SHADERS',
    defaultValue: false,
  );

  /// Re-enables the textured, two-pass Home ring on mobile web for controlled
  /// A/B testing when [enableNavbarShaders] is also enabled. The
  /// production-safe default keeps the static ring there while the skwasm
  /// runtime-effect crash is being isolated.
  static const bool enableMobileWebIridescentFeedback = bool.fromEnvironment(
    'ENABLE_MOBILE_WEB_IRIDESCENT_FEEDBACK',
    defaultValue: false,
  );
}
