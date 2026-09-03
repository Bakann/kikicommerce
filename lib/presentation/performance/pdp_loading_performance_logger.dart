import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class PdpLoadingPerformanceLogger {
  void tap({required String productId, required bool heroEligible});

  void dataReady({
    required String productId,
    required Duration latency,
    required bool heroEligible,
  });
}

class ConsolePdpLoadingPerformanceLogger
    implements PdpLoadingPerformanceLogger {
  const ConsolePdpLoadingPerformanceLogger();

  @override
  void tap({required String productId, required bool heroEligible}) {
    debugPrint(
      '[perf] PDP_LOADING_TAP product_id=$productId '
      'hero_eligible=$heroEligible',
    );
  }

  @override
  void dataReady({
    required String productId,
    required Duration latency,
    required bool heroEligible,
  }) {
    debugPrint(
      '[perf] PDP_LOADING_DATA_READY product_id=$productId '
      '${latency.inMilliseconds}ms hero_eligible=$heroEligible',
    );
  }
}

class NoopPdpLoadingPerformanceLogger implements PdpLoadingPerformanceLogger {
  const NoopPdpLoadingPerformanceLogger();

  @override
  void tap({required String productId, required bool heroEligible}) {}

  @override
  void dataReady({
    required String productId,
    required Duration latency,
    required bool heroEligible,
  }) {}
}

final pdpLoadingPerformanceLoggerProvider =
    Provider<PdpLoadingPerformanceLogger>((ref) {
      return kReleaseMode
          ? const NoopPdpLoadingPerformanceLogger()
          : const ConsolePdpLoadingPerformanceLogger();
    });
