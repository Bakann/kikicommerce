import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'foil_tilt_source.dart';

FoilTiltSource createFoilTiltSource() => _AccelerometerFoilTiltSource();

class _AccelerometerFoilTiltSource implements FoilTiltSource {
  static const double _movementRangeRadians = 0.45;

  StreamSubscription<AccelerometerEvent>? _subscription;
  FoilTiltListener? _listener;
  double? _baselineHorizontal;
  double? _baselineVertical;
  bool _disposed = false;

  @override
  bool get requiresUserGesture => false;

  @override
  Future<bool> start(FoilTiltListener listener) async {
    if (_disposed) return false;
    _listener = listener;
    if (_subscription != null) return true;

    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 32),
      ).listen(_onSample, onError: _onError, cancelOnError: true);
      return true;
    } catch (_) {
      _listener?.call(null);
      return false;
    }
  }

  void _onSample(AccelerometerEvent event) {
    final horizontal = math.atan2(
      event.x,
      math.sqrt(event.y * event.y + event.z * event.z),
    );
    final vertical = math.atan2(
      event.y,
      math.sqrt(event.x * event.x + event.z * event.z),
    );
    _baselineHorizontal ??= horizontal;
    _baselineVertical ??= vertical;

    _listener?.call(
      FoilTilt(
        horizontal:
            ((horizontal - _baselineHorizontal!) / _movementRangeRadians).clamp(
              -1.0,
              1.0,
            ),
        vertical: ((vertical - _baselineVertical!) / _movementRangeRadians)
            .clamp(-1.0, 1.0),
      ),
    );
  }

  void _onError(Object _) {
    final listener = _listener;
    stop();
    listener?.call(null);
  }

  @override
  void recenter() {
    _baselineHorizontal = null;
    _baselineVertical = null;
  }

  @override
  void stop() {
    final subscription = _subscription;
    _subscription = null;
    _listener = null;
    recenter();
    unawaited(subscription?.cancel());
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
  }
}
