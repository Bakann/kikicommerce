import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const kHeroImageBackButtonKey = ValueKey<String>('hero-image-back-button');
const kHeroImageBackButtonSize = 46.0;
const kHeroImageBackButtonTopGap = 16.0;
const kHeroImageBackButtonLeftGap = 18.0;

class HeroImageBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Key buttonKey;
  final bool triggerBubblePop;

  const HeroImageBackButton({
    super.key,
    required this.onPressed,
    this.buttonKey = kHeroImageBackButtonKey,
    this.triggerBubblePop = false,
  });

  @override
  Widget build(BuildContext context) {
    return HeroImageGlassIconButton(
      buttonKey: buttonKey,
      tooltip: 'Retour',
      semanticsLabel: 'Retour',
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, size: 23, color: Color(0xE6000000)),
      triggerBubblePop: triggerBubblePop,
    );
  }
}

class HeroImageGlassIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final String semanticsLabel;
  final Widget icon;
  final Key? buttonKey;
  final double dimension;
  final bool triggerBubblePop;

  const HeroImageGlassIconButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.semanticsLabel,
    required this.icon,
    this.buttonKey,
    this.dimension = kHeroImageBackButtonSize,
    this.triggerBubblePop = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              key: buttonKey,
              color: Colors.white.withValues(alpha: 0.38),
              shape: CircleBorder(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.62),
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: dimension,
                  child: Center(child: icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      return button;
    }

    return _BubblePopButton(
      triggerBubblePop: triggerBubblePop,
      dimension: dimension,
      child: button,
    );
  }
}

const double _kBubblePopOverflow = 30.0;

class _BubblePopButton extends StatefulWidget {
  final bool triggerBubblePop;
  final double dimension;
  final Widget child;

  const _BubblePopButton({
    required this.triggerBubblePop,
    required this.dimension,
    required this.child,
  });

  @override
  State<_BubblePopButton> createState() => _BubblePopButtonState();
}

class _BubblePopButtonState extends State<_BubblePopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 660),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 1,
        end: 0.94,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 18,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 0.94,
        end: 1.04,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 34,
    ),
    TweenSequenceItem<double>(
      tween: Tween<double>(
        begin: 1.04,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 48,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.triggerBubblePop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_BubblePopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.triggerBubblePop && widget.triggerBubblePop) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectSize = widget.dimension + (_kBubblePopOverflow * 2);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        final isAnimating = progress > 0 && progress < 1;
        return SizedBox.square(
          dimension: widget.dimension,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(scale: _scale.value, child: child),
              if (isAnimating)
                IgnorePointer(
                  child: OverflowBox(
                    minWidth: effectSize,
                    maxWidth: effectSize,
                    minHeight: effectSize,
                    maxHeight: effectSize,
                    child: SizedBox.square(
                      dimension: effectSize,
                      child: CustomPaint(
                        painter: _BubblePopPainter(
                          progress: progress,
                          buttonDimension: widget.dimension,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isAnimating)
                IgnorePointer(
                  child: Opacity(
                    opacity: _sheenOpacity(progress),
                    child: ClipOval(
                      child: SizedBox.square(
                        dimension: widget.dimension,
                        child: Transform.translate(
                          offset: Offset(
                            ui.lerpDouble(-16, 18, _easeOutCubic(progress))!,
                            0,
                          ),
                          child: Transform.rotate(
                            angle: -0.55,
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: widget.dimension * 0.34,
                                height: widget.dimension * 1.35,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.34),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: const [0.05, 0.5, 0.95],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _sheenOpacity(double progress) {
    final t = _interval(progress, 0.12, 0.68);
    return math.sin(t * math.pi).clamp(0.0, 1.0) * 0.48;
  }
}

class _BubblePopPainter extends CustomPainter {
  final double progress;
  final double buttonDimension;

  const _BubblePopPainter({
    required this.progress,
    required this.buttonDimension,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = buttonDimension / 2;

    // Expanding contour ring: it starts at the button edge and dissolves out.
    final ringT = _easeOutCubic(_interval(progress, 0.03, 0.86));
    final ringAlpha = 1 - ringT;
    final ringShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ui.lerpDouble(3.4, 0.8, ringT)!
      ..color = const Color(0xFF2F383B).withValues(alpha: ringAlpha * 0.24);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ui.lerpDouble(2.6, 0.45, ringT)!
      ..color = Colors.white.withValues(alpha: ringAlpha * 0.9);
    final iridescentBluePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ui.lerpDouble(2.0, 0.35, ringT)!
      ..color = const Color(0xFF9FE8FF).withValues(alpha: ringAlpha * 0.44);
    final iridescentPinkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ui.lerpDouble(1.7, 0.3, ringT)!
      ..color = const Color(0xFFFFC3E5).withValues(alpha: ringAlpha * 0.36);
    final ringRadius = baseRadius + ui.lerpDouble(1.2, 23, ringT)!;
    final iridescentRect = Rect.fromCircle(center: center, radius: ringRadius);
    canvas.drawCircle(
      center,
      baseRadius + ui.lerpDouble(1.8, 24, ringT)!,
      ringShadowPaint,
    );
    canvas.drawCircle(center, ringRadius, ringPaint);
    canvas.drawArc(iridescentRect, -1.35, 1.35, false, iridescentBluePaint);
    canvas.drawArc(iridescentRect, 1.35, 1.05, false, iridescentPinkPaint);

    // Small bubbles drift out on fixed arcs for a light soap-pop detail.
    const bubbles = <_BubbleParticle>[
      _BubbleParticle(angle: -2.34, delay: 0.00, distance: 17, radius: 2.0),
      _BubbleParticle(angle: -1.45, delay: 0.05, distance: 22, radius: 2.7),
      _BubbleParticle(angle: -0.45, delay: 0.02, distance: 20, radius: 2.2),
      _BubbleParticle(angle: 0.38, delay: 0.10, distance: 18, radius: 1.8),
      _BubbleParticle(angle: 1.22, delay: 0.07, distance: 21, radius: 2.4),
      _BubbleParticle(angle: 2.42, delay: 0.14, distance: 16, radius: 1.7),
    ];
    for (final bubble in bubbles) {
      final t = _interval(progress, bubble.delay, 0.94);
      if (t <= 0 || t >= 1) continue;
      final eased = _easeOutCubic(t);
      final distance = baseRadius + bubble.distance + (14 * eased);
      final offset = Offset(
        math.cos(bubble.angle) * distance,
        math.sin(bubble.angle) * distance,
      );
      final alpha = math.sin(t * math.pi) * 0.36;
      final bubbleFillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: alpha * 0.28);
      final bubbleShadowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(1.2, 0.55, t)!
        ..color = const Color(0xFF2F383B).withValues(alpha: alpha * 0.32);
      final bubblePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(1.2, 0.55, t)!
        ..color = Colors.white.withValues(alpha: alpha * 1.25);
      canvas.drawCircle(
        center + offset,
        bubble.radius + (1.4 * eased),
        bubbleFillPaint,
      );
      canvas.drawCircle(
        center + offset,
        bubble.radius + (1.4 * eased),
        bubbleShadowPaint,
      );
      canvas.drawCircle(
        center + offset,
        bubble.radius + (1.4 * eased),
        bubblePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePopPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.buttonDimension != buttonDimension;
  }
}

class _BubbleParticle {
  final double angle;
  final double delay;
  final double distance;
  final double radius;

  const _BubbleParticle({
    required this.angle,
    required this.delay,
    required this.distance,
    required this.radius,
  });
}

double _interval(double value, double begin, double end) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return (value - begin) / (end - begin);
}

double _easeOutCubic(double value) {
  return 1 - math.pow(1 - value, 3).toDouble();
}
