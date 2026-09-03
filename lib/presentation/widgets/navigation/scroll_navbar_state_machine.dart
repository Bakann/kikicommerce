import 'dart:math' as math;

class ScrollNavbarSnapshot {
  final bool isVisible;
  final double styleProgress;

  const ScrollNavbarSnapshot({
    required this.isVisible,
    required this.styleProgress,
  });

  static const initial = ScrollNavbarSnapshot(
    isVisible: true,
    styleProgress: 0,
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ScrollNavbarSnapshot &&
            other.isVisible == isVisible &&
            other.styleProgress == styleProgress;
  }

  @override
  int get hashCode => Object.hash(isVisible, styleProgress);
}

class ScrollNavbarStateMachine {
  static const double hideThreshold = 8;
  static const double showThreshold = 6;
  static const double topRevealZone = 12;

  double _lastOffset = 0;
  double _directionAccumulatedDelta = 0;
  int _lastDirection = 0;
  ScrollNavbarSnapshot _snapshot = ScrollNavbarSnapshot.initial;

  ScrollNavbarSnapshot get snapshot => _snapshot;

  ScrollNavbarSnapshot update({
    required double offset,
    required double heroHeight,
    bool forceVisibleLight = false,
  }) {
    final clampedOffset = math.max(0.0, offset);
    final styleProgress = _styleProgressFor(
      offset: clampedOffset,
      heroHeight: heroHeight,
      forceLight: forceVisibleLight,
    );

    if (forceVisibleLight) {
      _lastOffset = clampedOffset;
      _resetDirectionTracking();
      _snapshot = ScrollNavbarSnapshot(
        isVisible: true,
        styleProgress: styleProgress,
      );
      return _snapshot;
    }

    final delta = clampedOffset - _lastOffset;
    final direction = delta > 0
        ? 1
        : delta < 0
        ? -1
        : 0;
    _trackDirectionDelta(delta: delta, direction: direction);
    var nextVisible = _snapshot.isVisible;

    if (clampedOffset <= topRevealZone) {
      nextVisible = true;
      _resetDirectionTracking();
    } else if (direction > 0 && _directionAccumulatedDelta > hideThreshold) {
      nextVisible = false;
      _resetDirectionTracking();
    } else if (direction < 0 && _directionAccumulatedDelta > showThreshold) {
      nextVisible = true;
      _resetDirectionTracking();
    }

    _lastOffset = clampedOffset;
    _snapshot = ScrollNavbarSnapshot(
      isVisible: nextVisible,
      styleProgress: styleProgress,
    );
    return _snapshot;
  }

  static double _styleProgressFor({
    required double offset,
    required double heroHeight,
    required bool forceLight,
  }) {
    if (forceLight || heroHeight <= 0) {
      return 1;
    }
    if (offset <= 0) {
      return 0;
    }

    final transitionStart = heroHeight * 0.45;
    final transitionEnd = heroHeight * 0.80;
    final progress =
        (offset - transitionStart) / (transitionEnd - transitionStart);
    return _roundProgress(progress.clamp(0.0, 1.0));
  }

  static double _roundProgress(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  void _trackDirectionDelta({required double delta, required int direction}) {
    if (direction == 0) {
      return;
    }
    if (direction != _lastDirection) {
      _directionAccumulatedDelta = delta.abs();
      _lastDirection = direction;
      return;
    }
    _directionAccumulatedDelta += delta.abs();
  }

  void _resetDirectionTracking() {
    _directionAccumulatedDelta = 0;
    _lastDirection = 0;
  }
}
