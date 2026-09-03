import 'foil_tilt_source.dart';
import 'foil_tilt_source_stub.dart'
    if (dart.library.io) 'foil_tilt_source_io.dart'
    if (dart.library.js_interop) 'foil_tilt_source_web.dart'
    as platform;

export 'foil_tilt_source.dart';

FoilTiltSource createFoilTiltSource() => platform.createFoilTiltSource();
