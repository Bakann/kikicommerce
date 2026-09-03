/// Relative device tilt, normalised to the `[-1, 1]` range on each axis.
class FoilTilt {
  final double horizontal;
  final double vertical;

  const FoilTilt({required this.horizontal, required this.vertical});
}

typedef FoilTiltListener = void Function(FoilTilt? tilt);

/// Platform source used by the PDP foil interaction.
///
/// [start] must be called synchronously from a user gesture on platforms that
/// require an explicit motion permission. A `null` listener value means that
/// the sensor became unavailable and the visual should fall back gracefully.
abstract interface class FoilTiltSource {
  /// Whether [start] must be invoked synchronously from a user gesture.
  bool get requiresUserGesture;

  Future<bool> start(FoilTiltListener listener);

  void stop();

  void recenter();

  void dispose();
}

typedef FoilTiltSourceFactory = FoilTiltSource Function();
