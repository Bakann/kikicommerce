import 'foil_tilt_source.dart';

FoilTiltSource createFoilTiltSource() => _UnsupportedFoilTiltSource();

class _UnsupportedFoilTiltSource implements FoilTiltSource {
  @override
  bool get requiresUserGesture => false;

  @override
  Future<bool> start(FoilTiltListener listener) async => false;

  @override
  void stop() {}

  @override
  void recenter() {}

  @override
  void dispose() {}
}
