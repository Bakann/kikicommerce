export 'scroll_line_reveal_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum TextRevealTrigger { mount, viewport }

class TextRevealItem extends StatelessWidget {
  final Widget child;

  const TextRevealItem({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class TextRevealGroup extends StatefulWidget {
  final List<Widget> children;
  final TextRevealTrigger trigger;
  final bool enabled;
  final Duration duration;
  final Duration stagger;
  final Curve curve;
  final double translateY;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final VerticalDirection verticalDirection;
  final TextDirection? textDirection;
  final TextBaseline? textBaseline;

  const TextRevealGroup({
    super.key,
    required this.children,
    this.trigger = TextRevealTrigger.viewport,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 720),
    this.stagger = const Duration(milliseconds: 120),
    this.curve = Curves.easeOutCubic,
    this.translateY = 24,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.verticalDirection = VerticalDirection.down,
    this.textDirection,
    this.textBaseline,
  });

  @override
  State<TextRevealGroup> createState() => TextRevealGroupState();
}

class TextRevealGroupState extends State<TextRevealGroup>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  ScrollPosition? _scrollPosition;
  bool _frameScheduled = false;
  bool _hasStarted = false;
  bool _hasCompleted = false;
  int _frameToken = 0;

  @visibleForTesting
  bool get debugHasStarted => _hasStarted;

  @visibleForTesting
  bool get debugHasCompleted => _hasCompleted;

  @visibleForTesting
  bool get debugHasController => _controller != null;

  @visibleForTesting
  bool get debugHasScrollListener => _scrollPosition != null;

  int get _revealableCount =>
      widget.children.whereType<TextRevealItem>().length;

  bool get _canAnimate {
    if (!widget.enabled) return false;
    if (_revealableCount == 0) return false;
    return !MediaQuery.disableAnimationsOf(context);
  }

  Duration get _controllerDuration {
    final extraStagger = widget.stagger * (_revealableCount - 1);
    return widget.duration + extraStagger;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionState();
  }

  @override
  void didUpdateWidget(covariant TextRevealGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasStarted &&
        (oldWidget.duration != widget.duration ||
            oldWidget.stagger != widget.stagger ||
            oldWidget.children.length != widget.children.length)) {
      _controller?.duration = _controllerDuration;
    }
    _syncMotionState();
  }

  @override
  void dispose() {
    _cancelScheduledFrame();
    _detachScrollListener();
    _disposeController();
    super.dispose();
  }

  void _syncMotionState() {
    if (!mounted) return;
    if (!_canAnimate) {
      _completeWithoutAnimation();
      return;
    }
    if (_hasStarted || _hasCompleted) {
      return;
    }
    _ensureController();
    _scheduleTriggerCheck();
  }

  void _ensureController() {
    if (_controller != null) {
      _controller!.duration = _controllerDuration;
      return;
    }
    _controller = AnimationController(
      vsync: this,
      duration: _controllerDuration,
    )..addStatusListener(_handleControllerStatus);
  }

  void _handleControllerStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _hasCompleted = true;
    });
  }

  void _completeWithoutAnimation() {
    _cancelScheduledFrame();
    _detachScrollListener();
    _disposeController();
    if (_hasStarted && _hasCompleted) return;
    _hasStarted = true;
    _hasCompleted = true;
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeStatusListener(_handleControllerStatus);
    controller.dispose();
    _controller = null;
  }

  void _detachScrollListener() {
    final position = _scrollPosition;
    if (position == null) return;
    position.removeListener(_handleScroll);
    _scrollPosition = null;
  }

  void _attachScrollListener(ScrollPosition position) {
    if (identical(_scrollPosition, position)) return;
    _detachScrollListener();
    _scrollPosition = position;
    position.addListener(_handleScroll);
  }

  void _handleScroll() {
    _scheduleTriggerCheck();
  }

  void _scheduleTriggerCheck() {
    if (_frameScheduled || _hasStarted || _hasCompleted) return;
    _frameScheduled = true;
    final token = ++_frameToken;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted || token != _frameToken) return;
      _checkTrigger();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _cancelScheduledFrame() {
    _frameScheduled = false;
    _frameToken++;
  }

  void _checkTrigger() {
    if (!_canAnimate) {
      _completeWithoutAnimation();
      return;
    }
    if (_hasStarted || _hasCompleted) return;

    if (widget.trigger == TextRevealTrigger.mount) {
      _startReveal();
      return;
    }

    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) {
      _startReveal();
      return;
    }

    _attachScrollListener(scrollable.position);
    if (_isVisibleInViewport()) {
      _startReveal();
    }
  }

  bool _isVisibleInViewport() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    return bottom > 0 && top < viewportHeight;
  }

  void _startReveal() {
    if (_hasStarted || _hasCompleted) return;
    _cancelScheduledFrame();
    _detachScrollListener();
    _ensureController();
    setState(() {
      _hasStarted = true;
    });
    _controller!.forward();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final shouldRenderDirect =
        !_canAnimate || _hasCompleted || controller == null;

    if (shouldRenderDirect) {
      return _column(children: _plainChildren());
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return _column(children: _animatedChildren(controller.value));
      },
    );
  }

  Widget _column({required List<Widget> children}) {
    return Column(
      mainAxisAlignment: widget.mainAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      crossAxisAlignment: widget.crossAxisAlignment,
      verticalDirection: widget.verticalDirection,
      textDirection: widget.textDirection,
      textBaseline: widget.textBaseline,
      children: children,
    );
  }

  List<Widget> _plainChildren() {
    return [
      for (final child in widget.children)
        if (child is TextRevealItem) child.child else child,
    ];
  }

  List<Widget> _animatedChildren(double controllerValue) {
    var revealIndex = 0;
    return [
      for (final child in widget.children)
        if (child is TextRevealItem)
          _AnimatedRevealText(
            progress: _progressFor(
              controllerValue: controllerValue,
              index: revealIndex++,
            ),
            translateY: widget.translateY,
            child: child.child,
          )
        else
          child,
    ];
  }

  double _progressFor({required double controllerValue, required int index}) {
    final totalMs = _controllerDuration.inMilliseconds;
    if (totalMs <= 0) return 1;
    final start = (widget.stagger.inMilliseconds * index) / totalMs;
    final end =
        ((widget.stagger.inMilliseconds * index) +
            widget.duration.inMilliseconds) /
        totalMs;
    return Interval(
      start.clamp(0.0, 1.0),
      end.clamp(0.0, 1.0),
      curve: widget.curve,
    ).transform(controllerValue.clamp(0.0, 1.0));
  }
}

class _AnimatedRevealText extends StatelessWidget {
  final double progress;
  final double translateY;
  final Widget child;

  const _AnimatedRevealText({
    required this.progress,
    required this.translateY,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return child;
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * translateY),
        child: child,
      ),
    );
  }
}
