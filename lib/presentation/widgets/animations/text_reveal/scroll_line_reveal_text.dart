import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum ScrollLineRevealTextLayoutMode {
  nativeText,
  wordFirst,
  oversizedWordFallback,
}

class ScrollLineRevealText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool enabled;
  final Duration duration;
  final Duration wordStagger;
  final Duration lineStagger;
  final Curve curve;
  final double wordTranslateY;
  final double maxWordRotationDegrees;
  final double viewportRevealFraction;
  final bool animateWords;

  @Deprecated('Use lineStagger instead.')
  final Duration? stagger;

  @Deprecated('Use wordTranslateY instead.')
  final double? translateY;

  const ScrollLineRevealText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 600),
    this.wordStagger = const Duration(milliseconds: 45),
    Duration? lineStagger,
    this.curve = Curves.easeOutBack,
    double? wordTranslateY,
    this.maxWordRotationDegrees = 7,
    this.viewportRevealFraction = 0.85,
    this.animateWords = true,
    this.stagger,
    this.translateY,
  }) : lineStagger =
           lineStagger ?? stagger ?? const Duration(milliseconds: 110),
       wordTranslateY = wordTranslateY ?? translateY ?? -34;

  @override
  State<ScrollLineRevealText> createState() => ScrollLineRevealTextState();
}

class ScrollLineRevealTextState extends State<ScrollLineRevealText>
    with SingleTickerProviderStateMixin {
  static const double _widthTolerance = 0.75;
  static const double _minimumUsableWordWidth = 8;

  AnimationController? _controller;
  ScrollPosition? _scrollPosition;
  _LineMeasurementResult? _cachedMeasurement;
  List<_MeasuredTextLine> _lines = const [];
  ScrollLineRevealTextLayoutMode _layoutMode =
      ScrollLineRevealTextLayoutMode.nativeText;
  bool _frameScheduled = false;
  bool _needsControllerRebase = false;
  int? _cachedMeasurementSignature;
  int? _layoutSignature;
  int _frameToken = 0;
  int _targetLineCount = 0;
  int _layoutComputeCount = 0;
  int _tokenMeasureCount = 0;
  double? _lastScrollPixels;
  List<int?> _lineRevealStartMs = const [];
  // Memoized `_totalDurationMs`. Recomputing it is O(lines) and it is read
  // O(words) per line on every animation tick (via `_lineProgress` /
  // `_wordProgress`), so an uncached getter is O(words × lines) per frame.
  // Invalidated whenever `_lines`, `_lineRevealStartMs`, or a duration-shaping
  // widget property changes — never on a bare controller tick.
  int? _cachedTotalDurationMs;

  @visibleForTesting
  bool get debugHasController => _controller != null;

  @visibleForTesting
  int get debugLineCount => _lines.length;

  @visibleForTesting
  int get debugTargetLineCount => _targetLineCount;

  @visibleForTesting
  bool get debugHasCompleted =>
      _layoutMode != ScrollLineRevealTextLayoutMode.wordFirst ||
      !_canAnimate ||
      (_lines.isNotEmpty && _targetLineCount >= _lines.length);

  @visibleForTesting
  List<String> get debugVisualLines => [for (final line in _lines) line.text];

  @visibleForTesting
  bool get debugUsesGlobalFallback =>
      _layoutMode != ScrollLineRevealTextLayoutMode.wordFirst;

  @visibleForTesting
  ScrollLineRevealTextLayoutMode get debugLayoutMode => _layoutMode;

  @visibleForTesting
  int get debugLayoutComputeCount => _layoutComputeCount;

  @visibleForTesting
  int get debugTokenMeasureCount => _tokenMeasureCount;

  @visibleForTesting
  List<List<String>> get debugVisualLineSegments => [
    for (final line in _lines)
      [for (final segment in line.segments) segment.text],
  ];

  @visibleForTesting
  List<List<bool>> get debugVisualLineSegmentIsWord => [
    for (final line in _lines)
      [for (final segment in line.segments) segment.isWord],
  ];

  @visibleForTesting
  List<List<double>> get debugWordRotationsRadians => [
    for (final line in _lines)
      [
        for (final segment in line.segments)
          if (segment.isWord) _rotationRadiansForUnit(segment.rotationUnit),
      ],
  ];

  @visibleForTesting
  List<List<int>> get debugVisualLineWordIndexes => [
    for (final line in _lines)
      [for (final segment in line.segments) segment.wordIndex],
  ];

  @visibleForTesting
  List<bool> get debugLineFallbacks => [
    for (final line in _lines) line.usesFallback,
  ];

  @visibleForTesting
  List<double> get debugReconstructedLineWidths => [
    for (final line in _lines) line.reconstructedWidth,
  ];

  @visibleForTesting
  List<double> get debugLineMaxWidths => [
    for (final line in _lines) line.maxWidth,
  ];

  @visibleForTesting
  List<int?> get debugLineRevealStartMs =>
      List<int?>.unmodifiable(_lineRevealStartMs);

  @visibleForTesting
  Alignment get debugResolvedAlignment => _alignmentFor(
    _effectiveTextAlign(widget.textAlign),
    widget.textDirection ?? Directionality.of(context),
  );

  bool get _canAnimate {
    if (!widget.enabled) return false;
    if (widget.text.isEmpty) return false;
    return !MediaQuery.disableAnimationsOf(context);
  }

  bool get _usesAnimatedLayout =>
      _layoutMode == ScrollLineRevealTextLayoutMode.wordFirst;

  int get _totalDurationMs {
    return _cachedTotalDurationMs ??= _computeTotalDurationMs();
  }

  int _computeTotalDurationMs() {
    if (_lines.isEmpty) return math.max(1, widget.duration.inMilliseconds);
    var maxEndMs = widget.duration.inMilliseconds;
    for (var index = 0; index < _lines.length; index += 1) {
      maxEndMs = math.max(maxEndMs, _lineEndMs(index));
    }
    return math.max(1, maxEndMs);
  }

  void _invalidateTotalDuration() => _cachedTotalDurationMs = null;

  Duration get _totalDuration => Duration(milliseconds: _totalDurationMs);

  double get _verticalOverflow => widget.wordTranslateY.abs();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionState();
  }

  @override
  void didUpdateWidget(covariant ScrollLineRevealText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotionState();
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.textDirection != widget.textDirection ||
        oldWidget.wordStagger != widget.wordStagger ||
        oldWidget.lineStagger != widget.lineStagger ||
        oldWidget.duration != widget.duration ||
        oldWidget.animateWords != widget.animateWords) {
      _scheduleVisibilityUpdate();
    }
  }

  @override
  void dispose() {
    _cancelScheduledFrame();
    _detachScrollListener();
    _disposeController();
    super.dispose();
  }

  void _syncMotionState() {
    // A widget update may have changed a duration-shaping property before
    // `_ensureController` reads `_totalDuration` below.
    _invalidateTotalDuration();
    if (!_usesAnimatedLayout) {
      _completeWithoutAnimation();
      return;
    }
    if (!_canAnimate) {
      _completeWithoutAnimation();
      return;
    }
    _ensureController();
    _scheduleVisibilityUpdate();
  }

  AnimationController _ensureController() {
    final existing = _controller;
    if (existing != null) {
      existing.duration = _totalDuration;
      return existing;
    }
    return _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );
  }

  void _completeWithoutAnimation() {
    _cancelScheduledFrame();
    _detachScrollListener();
    _disposeController();
    _targetLineCount = _lines.length;
    _lineRevealStartMs = List<int?>.filled(_lines.length, 0);
    _needsControllerRebase = false;
    _invalidateTotalDuration();
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    controller.dispose();
    _controller = null;
  }

  void _attachScrollListener(ScrollPosition position) {
    if (identical(_scrollPosition, position)) return;
    _detachScrollListener();
    _scrollPosition = position;
    _lastScrollPixels = position.pixels;
    position.addListener(_handleScroll);
  }

  void _detachScrollListener() {
    final position = _scrollPosition;
    if (position == null) return;
    position.removeListener(_handleScroll);
    _scrollPosition = null;
    _lastScrollPixels = null;
  }

  void _handleScroll() {
    final position = _scrollPosition;
    if (position == null) return;
    final pixels = position.pixels;
    final previous = _lastScrollPixels;
    _lastScrollPixels = pixels;
    final isScrollingDown = previous == null || pixels > previous + 0.5;
    if (isScrollingDown) {
      _scheduleVisibilityUpdate();
    }
  }

  void _scheduleVisibilityUpdate() {
    if (_frameScheduled || !_canAnimate || !_usesAnimatedLayout) return;
    _frameScheduled = true;
    final token = ++_frameToken;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted || token != _frameToken) return;
      _updateVisibleLines();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _cancelScheduledFrame() {
    _frameScheduled = false;
    _frameToken++;
  }

  void _updateVisibleLines() {
    if (!_usesAnimatedLayout) {
      _completeWithoutAnimation();
      return;
    }
    if (!_canAnimate) {
      _completeWithoutAnimation();
      return;
    }
    if (_lines.isEmpty) return;

    _rebaseControllerIfNeeded();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      _revealThroughLine(_lines.length);
      return;
    }

    _attachScrollListener(scrollable.position);
    _revealThroughLine(_revealableLineCount());
  }

  void _rebaseControllerIfNeeded() {
    if (!_needsControllerRebase) return;
    _needsControllerRebase = false;
    final controller = _controller;
    if (controller == null) return;
    final cap = _controllerValueForLineCount(_targetLineCount);
    if (controller.value > cap) {
      controller.value = cap;
    }
  }

  int _revealableLineCount() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return 0;
    }

    final widgetTop = renderObject.localToGlobal(Offset.zero).dy;
    final revealFraction = widget.viewportRevealFraction
        .clamp(0.0, 1.0)
        .toDouble();
    final viewportThreshold =
        MediaQuery.sizeOf(context).height * revealFraction;
    var lastRevealableIndex = -1;
    for (var index = 0; index < _lines.length; index += 1) {
      final lineTop = widgetTop + _lines[index].top;
      if (lineTop < viewportThreshold) {
        lastRevealableIndex = index;
      }
    }
    return lastRevealableIndex + 1;
  }

  void _revealThroughLine(int lineCount) {
    if (!_usesAnimatedLayout) return;
    if (!_canAnimate || _lines.isEmpty) return;
    final nextTarget = lineCount.clamp(0, _lines.length).toInt();
    if (nextTarget <= _targetLineCount) return;
    final controller = _ensureController();
    final previousTotalDurationMs = _totalDurationMs;
    final currentTimelineMs = (controller.value * previousTotalDurationMs)
        .round();

    setState(() {
      _assignRevealStartTimes(
        fromLine: _targetLineCount,
        toLine: nextTarget,
        currentTimelineMs: currentTimelineMs,
      );
      _targetLineCount = nextTarget;
    });

    controller.stop(canceled: false);
    controller.duration = _totalDuration;
    controller.value = (currentTimelineMs / _totalDurationMs)
        .clamp(0.0, 1.0)
        .toDouble();
    final targetValue = _controllerValueForLineCount(nextTarget);
    if (targetValue <= controller.value) return;

    final duration = _durationForControllerDistance(
      (targetValue - controller.value).abs(),
    );
    controller
        .animateTo(targetValue, duration: duration, curve: Curves.linear)
        .whenComplete(() {
          if (mounted) {
            setState(() {});
          }
        });
  }

  void _syncRevealStartListLength() {
    _invalidateTotalDuration();
    if (_lines.isEmpty) {
      _lineRevealStartMs = const [];
      return;
    }
    final previous = _lineRevealStartMs;
    _lineRevealStartMs = List<int?>.generate(_lines.length, (index) {
      if (index >= previous.length) return null;
      return previous[index];
    });
  }

  void _assignRevealStartTimes({
    required int fromLine,
    required int toLine,
    required int currentTimelineMs,
  }) {
    _syncRevealStartListLength();
    if (fromLine >= toLine) return;
    final lineDelayMs = widget.lineStagger.inMilliseconds;
    final lastAssignedStartMs = _lastAssignedRevealStartMs;
    final firstStartMs = lastAssignedStartMs == null
        ? currentTimelineMs
        : math.max(currentTimelineMs, lastAssignedStartMs + lineDelayMs);

    for (var index = fromLine; index < toLine; index += 1) {
      _lineRevealStartMs[index] =
          firstStartMs + (index - fromLine) * lineDelayMs;
    }
    _invalidateTotalDuration();
  }

  int? get _lastAssignedRevealStartMs {
    int? latest;
    for (final startMs in _lineRevealStartMs) {
      if (startMs == null) continue;
      latest = latest == null ? startMs : math.max(latest, startMs);
    }
    return latest;
  }

  double _controllerValueForLineCount(int lineCount) {
    if (_lines.isEmpty || lineCount <= 0) return 0;
    final lineIndex = (lineCount - 1).clamp(0, _lines.length - 1).toInt();
    return (_lineEndMs(lineIndex) / _totalDurationMs).clamp(0.0, 1.0);
  }

  Duration _durationForControllerDistance(double distance) {
    final ms = (_totalDurationMs * distance).round().clamp(
      120,
      _totalDurationMs,
    );
    return Duration(milliseconds: ms);
  }

  int _lineStartMs(int lineIndex) {
    if (lineIndex >= 0 && lineIndex < _lineRevealStartMs.length) {
      final assignedStartMs = _lineRevealStartMs[lineIndex];
      if (assignedStartMs != null) return assignedStartMs;
    }
    return widget.lineStagger.inMilliseconds * lineIndex;
  }

  int _lineEndMs(int lineIndex) {
    final line = _lines[lineIndex];
    final wordCount = line.animatableWordCount;
    final wordDelay = widget.animateWords && !line.usesFallback && wordCount > 0
        ? widget.wordStagger.inMilliseconds * (wordCount - 1)
        : 0;
    return _lineStartMs(lineIndex) + wordDelay + widget.duration.inMilliseconds;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(widget.style);
    final direction = widget.textDirection ?? Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final shouldAnimate = _canAnimate;

    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final measurement = _measureLines(
              maxWidth: maxWidth,
              style: effectiveStyle,
              direction: direction,
              textScaler: textScaler,
              shouldAnimate: shouldAnimate,
            );
            _syncMeasuredLines(
              measurement: measurement,
              maxWidth: maxWidth,
              style: effectiveStyle,
              direction: direction,
              textScaler: textScaler,
              shouldAnimate: shouldAnimate,
            );

            if (!_usesAnimatedLayout) {
              return _buildNativeText(
                maxWidth: maxWidth,
                style: effectiveStyle,
                direction: direction,
                textScaler: textScaler,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < _lines.length; index += 1)
                  _buildLine(
                    line: _lines[index],
                    lineIndex: index,
                    maxWidth: maxWidth,
                    style: effectiveStyle,
                    direction: direction,
                    textScaler: textScaler,
                    animate: shouldAnimate,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _syncMeasuredLines({
    required _LineMeasurementResult measurement,
    required double maxWidth,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required bool shouldAnimate,
  }) {
    // `_lines` and `_lineRevealStartMs` are both reassigned below.
    _invalidateTotalDuration();
    final signature = Object.hash(
      widget.text,
      maxWidth,
      style,
      direction,
      textScaler,
      widget.textAlign,
      widget.animateWords,
      measurement.layoutMode,
    );
    final layoutChanged = _layoutSignature != signature;
    _layoutSignature = signature;
    final previousTarget = _targetLineCount;
    _layoutMode = measurement.layoutMode;
    _lines = measurement.lines;

    if (!_usesAnimatedLayout) {
      _lineRevealStartMs = const [];
      _completeWithoutAnimation();
      return;
    }

    if (!shouldAnimate) {
      _targetLineCount = _lines.length;
      _lineRevealStartMs = List<int?>.filled(_lines.length, 0);
      return;
    }

    _targetLineCount = previousTarget.clamp(0, _lines.length).toInt();
    _syncRevealStartListLength();
    _ensureController();
    if (layoutChanged) {
      _needsControllerRebase = true;
    }
    _scheduleVisibilityUpdate();
  }

  _LineMeasurementResult _measureLines({
    required double maxWidth,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required bool shouldAnimate,
  }) {
    final measurementSignature = Object.hash(
      widget.text,
      maxWidth,
      style,
      textScaler,
      direction,
      _effectiveTextAlign(widget.textAlign),
      widget.animateWords,
    );
    final wantsNativeText =
        !shouldAnimate ||
        widget.text.isEmpty ||
        !maxWidth.isFinite ||
        maxWidth <= 0;
    final cachedMeasurement = _cachedMeasurement;
    if (_cachedMeasurementSignature == measurementSignature &&
        cachedMeasurement != null) {
      if (wantsNativeText &&
          cachedMeasurement.layoutMode ==
              ScrollLineRevealTextLayoutMode.nativeText) {
        return cachedMeasurement;
      }
      if (!wantsNativeText &&
          cachedMeasurement.layoutMode !=
              ScrollLineRevealTextLayoutMode.nativeText) {
        return cachedMeasurement;
      }
    }

    _layoutComputeCount += 1;
    final lineHeight = _measureLineHeight(
      style: style,
      direction: direction,
      textScaler: textScaler,
    );

    if (!shouldAnimate || widget.text.isEmpty) {
      return _cacheMeasurement(
        signature: measurementSignature,
        measurement: _nativeMeasurement(
          maxWidth: maxWidth,
          lineHeight: lineHeight,
          style: style,
          direction: direction,
          textScaler: textScaler,
          layoutMode: ScrollLineRevealTextLayoutMode.nativeText,
        ),
      );
    }

    if (!maxWidth.isFinite || maxWidth <= 0) {
      return _cacheMeasurement(
        signature: measurementSignature,
        measurement: _nativeMeasurement(
          maxWidth: maxWidth,
          lineHeight: lineHeight,
          style: style,
          direction: direction,
          textScaler: textScaler,
          layoutMode: ScrollLineRevealTextLayoutMode.nativeText,
        ),
      );
    }

    final tokens = _tokensForText(
      style: style,
      direction: direction,
      textScaler: textScaler,
    );
    final drafts = <_LineDraft>[];
    var current = _LineDraft();
    var pendingSpaceText = '';
    var pendingSpaceWidth = 0.0;

    void finishLine({bool preserveEmpty = false}) {
      if (current.hasContent || preserveEmpty) {
        drafts.add(current);
      }
      current = _LineDraft();
      pendingSpaceText = '';
      pendingSpaceWidth = 0;
    }

    for (final token in tokens) {
      switch (token.kind) {
        case _TextTokenKind.space:
          pendingSpaceText += token.text;
          pendingSpaceWidth += token.width;
        case _TextTokenKind.newline:
          finishLine(preserveEmpty: true);
        case _TextTokenKind.word:
          if (token.width > maxWidth + _widthTolerance &&
              maxWidth <= _minimumUsableWordWidth) {
            return _cacheMeasurement(
              signature: measurementSignature,
              measurement: _nativeMeasurement(
                maxWidth: maxWidth,
                lineHeight: lineHeight,
                style: style,
                direction: direction,
                textScaler: textScaler,
                layoutMode:
                    ScrollLineRevealTextLayoutMode.oversizedWordFallback,
              ),
            );
          }

          final includeLeadingSpace = current.hasContent;
          final groupWidth =
              token.width + (includeLeadingSpace ? pendingSpaceWidth : 0);
          if (current.hasContent &&
              current.width + groupWidth > maxWidth + _widthTolerance) {
            finishLine();
          }

          if (current.hasContent && pendingSpaceText.isNotEmpty) {
            current.addSpace(pendingSpaceText, pendingSpaceWidth);
          }
          current.addWord(token.text, token.width);
          pendingSpaceText = '';
          pendingSpaceWidth = 0;
      }
    }

    finishLine();

    final lines = <_MeasuredTextLine>[
      for (var lineIndex = 0; lineIndex < drafts.length; lineIndex += 1)
        _measuredLineFromDraft(
          draft: drafts[lineIndex],
          lineIndex: lineIndex,
          lineHeight: lineHeight,
          maxWidth: maxWidth,
        ),
    ];

    return _cacheMeasurement(
      signature: measurementSignature,
      measurement: _LineMeasurementResult(
        lines: lines,
        layoutMode: ScrollLineRevealTextLayoutMode.wordFirst,
      ),
    );
  }

  _LineMeasurementResult _cacheMeasurement({
    required int signature,
    required _LineMeasurementResult measurement,
  }) {
    _cachedMeasurementSignature = signature;
    _cachedMeasurement = measurement;
    return measurement;
  }

  _LineMeasurementResult _nativeMeasurement({
    required double maxWidth,
    required double lineHeight,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required ScrollLineRevealTextLayoutMode layoutMode,
  }) {
    return _LineMeasurementResult(
      lines: [
        _MeasuredTextLine(
          text: widget.text,
          top: 0,
          height: lineHeight,
          maxWidth: maxWidth,
          reconstructedWidth: _measureSegmentWidth(
            text: widget.text,
            style: style,
            direction: direction,
            textScaler: textScaler,
          ),
          usesFallback: true,
          segments: _debugSegmentsForText(
            text: widget.text,
            lineIndex: 0,
            style: style,
            direction: direction,
            textScaler: textScaler,
          ),
        ),
      ],
      layoutMode: layoutMode,
    );
  }

  _MeasuredTextLine _measuredLineFromDraft({
    required _LineDraft draft,
    required int lineIndex,
    required double lineHeight,
    required double maxWidth,
  }) {
    var wordIndex = 0;
    final segments = <_MeasuredWordSegment>[];
    for (final segment in draft.segments) {
      if (segment.isWord) {
        final currentWordIndex = wordIndex++;
        segments.add(
          _MeasuredWordSegment(
            text: segment.text,
            isWord: true,
            wordIndex: currentWordIndex,
            width: segment.width,
            rotationUnit: _stableRotationUnit(
              lineIndex: lineIndex,
              wordIndex: currentWordIndex,
            ),
          ),
        );
      } else {
        segments.add(
          _MeasuredWordSegment(
            text: segment.text,
            isWord: false,
            wordIndex: -1,
            width: segment.width,
            rotationUnit: 0,
          ),
        );
      }
    }
    return _MeasuredTextLine(
      text: draft.text,
      top: lineIndex * lineHeight,
      height: lineHeight,
      maxWidth: maxWidth,
      reconstructedWidth: draft.width,
      usesFallback: draft.width > maxWidth + _widthTolerance,
      segments: segments,
    );
  }

  Widget _buildNativeText({
    required double maxWidth,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
  }) {
    return SizedBox(
      width: maxWidth.isFinite && maxWidth > 0 ? maxWidth : null,
      child: Text(
        widget.text,
        style: style,
        textAlign: _effectiveTextAlign(widget.textAlign),
        textDirection: direction,
        textScaler: textScaler,
      ),
    );
  }

  List<_MeasuredWordSegment> _debugSegmentsForText({
    required String text,
    required int lineIndex,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
  }) {
    var wordIndex = 0;
    final segments = <_MeasuredWordSegment>[];
    for (final token in _tokensForText(
      text: text,
      style: style,
      direction: direction,
      textScaler: textScaler,
    )) {
      if (token.kind == _TextTokenKind.newline) continue;
      if (token.kind == _TextTokenKind.word) {
        final currentWordIndex = wordIndex++;
        segments.add(
          _MeasuredWordSegment(
            text: token.text,
            isWord: true,
            wordIndex: currentWordIndex,
            width: token.width,
            rotationUnit: _stableRotationUnit(
              lineIndex: lineIndex,
              wordIndex: currentWordIndex,
            ),
          ),
        );
      } else {
        segments.add(
          _MeasuredWordSegment(
            text: token.text,
            isWord: false,
            wordIndex: -1,
            width: token.width,
            rotationUnit: 0,
          ),
        );
      }
    }
    return segments;
  }

  List<_TextToken> _tokensForText({
    String? text,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
  }) {
    final source = text ?? widget.text;
    final tokens = <_TextToken>[];
    final buffer = StringBuffer();
    _TextTokenKind? currentKind;

    void flush() {
      if (buffer.isEmpty || currentKind == null) return;
      final tokenText = buffer.toString();
      tokens.add(
        _TextToken(
          kind: currentKind,
          text: tokenText,
          width: currentKind == _TextTokenKind.newline
              ? 0
              : _measureSegmentWidth(
                  text: tokenText,
                  style: style,
                  direction: direction,
                  textScaler: textScaler,
                ),
        ),
      );
      buffer.clear();
    }

    for (var index = 0; index < source.length; index += 1) {
      final codeUnit = source.codeUnitAt(index);
      final isNewline = codeUnit == 10 || codeUnit == 13;
      if (isNewline) {
        flush();
        if (codeUnit == 13 &&
            index + 1 < source.length &&
            source.codeUnitAt(index + 1) == 10) {
          index += 1;
        }
        tokens.add(
          const _TextToken(kind: _TextTokenKind.newline, text: '\n', width: 0),
        );
        currentKind = null;
        continue;
      }

      final kind = _isWhitespaceCodeUnit(codeUnit)
          ? _TextTokenKind.space
          : _TextTokenKind.word;
      if (currentKind != kind) {
        flush();
        currentKind = kind;
      }
      buffer.writeCharCode(codeUnit);
    }
    flush();
    return tokens;
  }

  bool _isWhitespaceCodeUnit(int codeUnit) {
    return codeUnit == 0x09 ||
        codeUnit == 0x0B ||
        codeUnit == 0x0C ||
        codeUnit == 0x20 ||
        codeUnit == 0x85 ||
        codeUnit == 0xA0 ||
        codeUnit == 0x1680 ||
        (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
        codeUnit == 0x2028 ||
        codeUnit == 0x2029 ||
        codeUnit == 0x202F ||
        codeUnit == 0x205F ||
        codeUnit == 0x3000;
  }

  double _measureLineHeight({
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
  }) {
    _tokenMeasureCount += 1;
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final metrics = painter.computeLineMetrics();
    if (metrics.isNotEmpty) return metrics.first.height;
    return painter.height;
  }

  double _measureSegmentWidth({
    required String text,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
  }) {
    if (text.isEmpty) return 0;
    _tokenMeasureCount += 1;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  Widget _buildLine({
    required _MeasuredTextLine line,
    required int lineIndex,
    required double maxWidth,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required bool animate,
  }) {
    final lineContent = line.usesFallback || !widget.animateWords
        ? _buildSimpleLine(
            line: line,
            lineIndex: lineIndex,
            style: style,
            direction: direction,
            textScaler: textScaler,
            animate: animate,
          )
        : _buildWordLine(
            line: line,
            lineIndex: lineIndex,
            style: style,
            direction: direction,
            textScaler: textScaler,
            animate: animate,
          );

    // The packer keeps a line whose reconstructed width is within
    // `_widthTolerance` of `maxWidth` on a single row, so the word Row can be a
    // sub-pixel wider than `maxWidth`. Size the inner box (and let the
    // OverflowBox stretch) to the actual content width so that hair of
    // horizontal overflow is absorbed — exactly how the OverflowBox already
    // absorbs the vertical overflow. Identical to before when content fits.
    final contentWidth = line.reconstructedWidth > maxWidth
        ? line.reconstructedWidth
        : maxWidth;
    return SizedBox(
      width: maxWidth,
      height: line.height,
      child: OverflowBox(
        minWidth: maxWidth,
        maxWidth: contentWidth,
        minHeight: line.height,
        maxHeight: line.height + _verticalOverflow,
        alignment: widget.wordTranslateY < 0
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        child: SizedBox(
          width: contentWidth,
          height: line.height,
          child: lineContent,
        ),
      ),
    );
  }

  Widget _buildSimpleLine({
    required _MeasuredTextLine line,
    required int lineIndex,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required bool animate,
  }) {
    final lineWidget = SizedBox(
      width: line.maxWidth,
      height: line.height,
      child: Text(
        line.text,
        style: style,
        textAlign: _effectiveTextAlign(widget.textAlign),
        textDirection: direction,
        textScaler: textScaler,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.visible,
      ),
    );

    if (!animate) {
      return lineWidget;
    }

    final controller = _controller;
    if (controller == null) {
      return Opacity(opacity: 0, child: lineWidget);
    }
    if (lineIndex >= _targetLineCount) {
      return Opacity(opacity: 0, child: lineWidget);
    }
    if (_lineCompletionProgress(line, lineIndex, controller.value) >= 1) {
      return lineWidget;
    }

    return AnimatedBuilder(
      animation: controller,
      child: lineWidget,
      builder: (context, child) {
        final progress = _lineProgress(lineIndex, controller.value);
        if (progress >= 1) return child!;
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * widget.wordTranslateY),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildWordLine({
    required _MeasuredTextLine line,
    required int lineIndex,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required bool animate,
  }) {
    final alignment = _alignmentFor(
      _effectiveTextAlign(widget.textAlign),
      direction,
    );
    if (!animate) {
      return Align(
        alignment: alignment,
        child: _wordRow(
          line: line,
          style: style,
          direction: direction,
          textScaler: textScaler,
          controllerValue: 1,
          animate: false,
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return Opacity(
        opacity: 0,
        child: Align(
          alignment: alignment,
          child: _wordRow(
            line: line,
            style: style,
            direction: direction,
            textScaler: textScaler,
            controllerValue: 0,
            animate: false,
          ),
        ),
      );
    }
    if (lineIndex >= _targetLineCount) {
      return Opacity(
        opacity: 0,
        child: Align(
          alignment: alignment,
          child: _wordRow(
            line: line,
            style: style,
            direction: direction,
            textScaler: textScaler,
            controllerValue: 1,
            animate: false,
          ),
        ),
      );
    }
    if (_lineCompletionProgress(line, lineIndex, controller.value) >= 1) {
      return Align(
        alignment: alignment,
        child: _wordRow(
          line: line,
          style: style,
          direction: direction,
          textScaler: textScaler,
          controllerValue: 1,
          animate: false,
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Align(
          alignment: alignment,
          child: _wordRow(
            line: line,
            lineIndex: lineIndex,
            style: style,
            direction: direction,
            textScaler: textScaler,
            controllerValue: controller.value,
            animate: true,
          ),
        );
      },
    );
  }

  Widget _wordRow({
    required _MeasuredTextLine line,
    int lineIndex = 0,
    required TextStyle style,
    required TextDirection direction,
    required TextScaler textScaler,
    required double controllerValue,
    required bool animate,
  }) {
    var previousWordProgress = animate
        ? _lineProgress(lineIndex, controllerValue)
        : 1.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: direction,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final segment in line.segments)
          if (segment.isWord)
            _wordSegment(
              segment: segment,
              lineIndex: lineIndex,
              style: style,
              textScaler: textScaler,
              controllerValue: controllerValue,
              progress: animate
                  ? previousWordProgress = _wordProgress(
                      lineIndex: lineIndex,
                      wordIndex: segment.wordIndex,
                      controllerValue: controllerValue,
                    )
                  : 1,
            )
          else
            Opacity(
              opacity: previousWordProgress,
              child: _plainSegment(segment, style, textScaler),
            ),
      ],
    );
  }

  Widget _wordSegment({
    required _MeasuredWordSegment segment,
    required int lineIndex,
    required TextStyle style,
    required TextScaler textScaler,
    required double controllerValue,
    required double progress,
  }) {
    final child = _plainSegment(segment, style, textScaler);
    if (progress >= 1) return child;

    final rotation = widget.maxWordRotationDegrees == 0
        ? 0.0
        : _rotationRadiansForUnit(segment.rotationUnit) * (1 - progress);
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * widget.wordTranslateY),
        child: Transform.rotate(angle: rotation, child: child),
      ),
    );
  }

  Widget _plainSegment(
    _MeasuredWordSegment segment,
    TextStyle style,
    TextScaler textScaler,
  ) {
    return Text(
      segment.text,
      style: style,
      textScaler: textScaler,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.visible,
    );
  }

  double _lineProgress(int lineIndex, double controllerValue) {
    final totalMs = _totalDurationMs;
    final start = _lineStartMs(lineIndex) / totalMs;
    final end =
        (_lineStartMs(lineIndex) + widget.duration.inMilliseconds) / totalMs;
    return Interval(
      start.clamp(0.0, 1.0),
      end.clamp(0.0, 1.0),
      curve: widget.curve,
    ).transform(controllerValue.clamp(0.0, 1.0)).clamp(0.0, 1.0).toDouble();
  }

  double _lineCompletionProgress(
    _MeasuredTextLine line,
    int lineIndex,
    double controllerValue,
  ) {
    final wordCount = line.animatableWordCount;
    if (widget.animateWords && !line.usesFallback && wordCount > 0) {
      return _wordProgress(
        lineIndex: lineIndex,
        wordIndex: wordCount - 1,
        controllerValue: controllerValue,
      );
    }
    return _lineProgress(lineIndex, controllerValue);
  }

  double _wordProgress({
    required int lineIndex,
    required int wordIndex,
    required double controllerValue,
  }) {
    final totalMs = _totalDurationMs;
    final startMs =
        _lineStartMs(lineIndex) +
        (widget.wordStagger.inMilliseconds * wordIndex);
    final endMs = startMs + widget.duration.inMilliseconds;
    return Interval(
      (startMs / totalMs).clamp(0.0, 1.0),
      (endMs / totalMs).clamp(0.0, 1.0),
      curve: widget.curve,
    ).transform(controllerValue.clamp(0.0, 1.0)).clamp(0.0, 1.0).toDouble();
  }

  double _stableRotationUnit({required int lineIndex, required int wordIndex}) {
    final hash = _stableHash('${widget.text}|$lineIndex|$wordIndex');
    final normalized = (hash % 10000) / 9999.0;
    return (normalized * 2) - 1;
  }

  double _rotationRadiansForUnit(double rotationUnit) {
    if (widget.maxWordRotationDegrees == 0) return 0;
    final maxRadians = widget.maxWordRotationDegrees * math.pi / 180;
    return rotationUnit * maxRadians;
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  TextAlign _effectiveTextAlign(TextAlign textAlign) {
    return textAlign == TextAlign.justify ? TextAlign.start : textAlign;
  }

  Alignment _alignmentFor(TextAlign textAlign, TextDirection direction) {
    switch (textAlign) {
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.end:
        return direction == TextDirection.rtl
            ? Alignment.centerLeft
            : Alignment.centerRight;
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.start:
      case TextAlign.justify:
        return direction == TextDirection.rtl
            ? Alignment.centerRight
            : Alignment.centerLeft;
    }
  }
}

class _MeasuredTextLine {
  final String text;
  final double top;
  final double height;
  final double maxWidth;
  final double reconstructedWidth;
  final bool usesFallback;
  final List<_MeasuredWordSegment> segments;

  const _MeasuredTextLine({
    required this.text,
    required this.top,
    required this.height,
    required this.maxWidth,
    required this.reconstructedWidth,
    required this.usesFallback,
    required this.segments,
  });

  int get animatableWordCount =>
      segments.where((segment) => segment.isWord).length;
}

class _LineMeasurementResult {
  final List<_MeasuredTextLine> lines;
  final ScrollLineRevealTextLayoutMode layoutMode;

  const _LineMeasurementResult({required this.lines, required this.layoutMode});
}

class _TextToken {
  final _TextTokenKind kind;
  final String text;
  final double width;

  const _TextToken({
    required this.kind,
    required this.text,
    required this.width,
  });
}

enum _TextTokenKind { word, space, newline }

class _LineDraft {
  final List<_DraftSegment> segments = [];
  double width = 0;

  bool get hasContent => segments.isNotEmpty;

  String get text => segments.map((segment) => segment.text).join();

  void addWord(String text, double segmentWidth) {
    segments.add(_DraftSegment(text: text, isWord: true, width: segmentWidth));
    width += segmentWidth;
  }

  void addSpace(String text, double segmentWidth) {
    segments.add(_DraftSegment(text: text, isWord: false, width: segmentWidth));
    width += segmentWidth;
  }
}

class _DraftSegment {
  final String text;
  final bool isWord;
  final double width;

  const _DraftSegment({
    required this.text,
    required this.isWord,
    required this.width,
  });
}

class _MeasuredWordSegment {
  final String text;
  final bool isWord;
  final int wordIndex;
  final double width;
  final double rotationUnit;

  const _MeasuredWordSegment({
    required this.text,
    required this.isWord,
    required this.wordIndex,
    required this.width,
    required this.rotationUnit,
  });
}
