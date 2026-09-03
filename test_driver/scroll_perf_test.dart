// Manual jank-profiling driver script (see
// docs/dev/storefront_performance_profiling.md). Not run by `flutter test` or
// CI. Drives real touch swipes on the connected device via adb while a
// FlutterDriver timeline trace is recording, then dumps a timeline + summary
// JSON so frame build/raster times can be inspected.
//
// Usage:
//   flutter drive \
//     --target=test_driver/app.dart \
//     --driver=test_driver/scroll_perf_test.dart \
//     --profile -d <device-id> --route=<route> \
//     --dart-define=PERF_UNUSED=1
//   (scenario name / swipe count / adb path are read from environment
//   variables set on the host shell, see PERF_* below)
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final scenario = Platform.environment['PERF_SCENARIO'] ?? 'scroll_perf';
  final swipes = int.parse(Platform.environment['PERF_SWIPES'] ?? '8');
  final deviceSerial = Platform.environment['PERF_DEVICE_SERIAL'];
  final adbPath = Platform.environment['PERF_ADB_PATH'] ?? 'adb';
  final outputDir = Platform.environment['PERF_OUTPUT_DIR'] ?? 'build/perf';

  final driver = await FlutterDriver.connect();
  // Let the route settle (first paint + catalog/CMS fetch) before recording
  // so the timeline only captures scroll frames, not cold-start work.
  await Future<void>.delayed(const Duration(seconds: 3));

  Future<void> swipe(int y1, int y2, int durationMs) async {
    final result = await Process.run(adbPath, [
      if (deviceSerial != null) ...['-s', deviceSerial],
      'shell',
      'input',
      'swipe',
      '540',
      '$y1',
      '540',
      '$y2',
      '$durationMs',
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('adb swipe failed: ${result.stderr}');
    }
  }

  final timeline = await driver.traceAction(() async {
    for (var i = 0; i < swipes; i++) {
      await swipe(1900, 400, 180);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    for (var i = 0; i < swipes; i++) {
      await swipe(400, 1900, 180);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  });

  final summary = TimelineSummary.summarize(timeline);
  await summary.writeTimelineToFile(
    scenario,
    destinationDirectory: outputDir,
    pretty: true,
  );

  await driver.close();
}
