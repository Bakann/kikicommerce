import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'foil_tilt_source.dart';

FoilTiltSource createFoilTiltSource() => _WebOrientationFoilTiltSource();

class _WebOrientationFoilTiltSource implements FoilTiltSource {
  static const double _movementRangeDegrees = 25;
  static const int _minimumSampleIntervalMicros = 16000;

  web.EventListener? _orientationListener;
  FoilTiltListener? _listener;
  final Stopwatch _sampleClock = Stopwatch()..start();
  int _lastSampleMicros = -_minimumSampleIntervalMicros;
  double? _baselineBeta;
  double? _baselineGamma;
  bool _permissionGranted = false;
  bool _disposed = false;

  @override
  bool get requiresUserGesture {
    final constructorValue = globalContext['DeviceOrientationEvent'];
    if (constructorValue == null) return false;
    return (constructorValue as JSObject).has('requestPermission');
  }

  @override
  Future<bool> start(FoilTiltListener listener) async {
    if (_disposed || !web.window.isSecureContext) return false;
    _listener = listener;
    if (_orientationListener != null) return true;
    if (!await _requestPermission()) {
      _listener = null;
      return false;
    }

    final orientationListener = _onOrientation.toJS;
    _orientationListener = orientationListener;
    web.window.addEventListener('deviceorientation', orientationListener);
    return true;
  }

  Future<bool> _requestPermission() async {
    if (_permissionGranted) return true;
    final constructorValue = globalContext['DeviceOrientationEvent'];
    if (constructorValue == null) return false;
    final constructor = constructorValue as JSObject;
    if (!constructor.has('requestPermission')) {
      _permissionGranted = true;
      return true;
    }

    try {
      final promise = constructor.callMethod<JSPromise<JSString>>(
        'requestPermission'.toJS,
      );
      final state = (await promise.toDart).toDart;
      _permissionGranted = state == 'granted';
      return _permissionGranted;
    } catch (_) {
      return false;
    }
  }

  void _onOrientation(web.DeviceOrientationEvent event) {
    final beta = event.beta;
    final gamma = event.gamma;
    if (beta == null || gamma == null) return;
    final now = _sampleClock.elapsedMicroseconds;
    if (now - _lastSampleMicros < _minimumSampleIntervalMicros) return;
    _lastSampleMicros = now;
    _baselineBeta ??= beta;
    _baselineGamma ??= gamma;

    _listener?.call(
      FoilTilt(
        horizontal: ((gamma - _baselineGamma!) / _movementRangeDegrees).clamp(
          -1.0,
          1.0,
        ),
        vertical: ((beta - _baselineBeta!) / _movementRangeDegrees).clamp(
          -1.0,
          1.0,
        ),
      ),
    );
  }

  @override
  void recenter() {
    _baselineBeta = null;
    _baselineGamma = null;
  }

  @override
  void stop() {
    final orientationListener = _orientationListener;
    _orientationListener = null;
    if (orientationListener != null) {
      web.window.removeEventListener('deviceorientation', orientationListener);
    }
    _listener = null;
    recenter();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
  }
}
