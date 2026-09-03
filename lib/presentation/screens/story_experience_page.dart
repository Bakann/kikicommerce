import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../../core/constants.dart';

/// Full-screen, scroll-jacking section pager — a Flutter reproduction of the
/// GSAP "Animated Sections" demo (https://codepen.io/BrianCross/pen/PoWapLP).
///
/// Each gesture (wheel / swipe / arrow key) advances exactly one section and the
/// list wraps around at both ends. A single [AnimationController] drives the
/// whole transition so nothing reads geometry per frame (jank conventions):
///
///  * a **curtain reveal** — `outer` and `inner` wrappers counter-translate
///    behind two clips so the frame wipes in while the image stays put;
///  * a **background parallax** — the incoming image drifts up into place while
///    the outgoing one drifts away;
///  * a **per-character heading** — letters rise from below a per-line clip
///    (GSAP `yPercent: 150` + `clip-text`) with a randomised stagger.
///
/// V1 ships with fixed [_slides]; the same widget can later be fed CMS-driven
/// slides without touching the animation.
class StoryExperiencePage extends StatefulWidget {
  const StoryExperiencePage({super.key});

  @override
  State<StoryExperiencePage> createState() => _StoryExperiencePageState();
}

class _StoryExperiencePageState extends State<StoryExperiencePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _transitionDuration,
  );

  int _currentIndex = 0;
  int _outgoingIndex = -1;
  // +1 = forward/down (next), -1 = backward/up (previous). Flips the sign of
  // every translate so up and down mirror each other, like GSAP's `dFactor`.
  int _direction = 1;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    // Play the first section's entrance once the first frame has a context
    // (needed for MediaQuery / precache).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheAround(_currentIndex);
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _animating = true;
        _controller.forward(from: 0).whenComplete(_onTransitionComplete);
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _wrap(int index) {
    final n = _slides.length;
    return (index % n + n) % n;
  }

  void _onTransitionComplete() {
    if (!mounted) return;
    setState(() {
      _animating = false;
      _outgoingIndex = -1;
    });
  }

  void _go(int delta) {
    if (_animating || delta == 0) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _outgoingIndex = _currentIndex;
      _direction = delta < 0 ? -1 : 1;
      _currentIndex = _wrap(_currentIndex + delta);
      _animating = !reduceMotion;
    });
    _precacheAround(_currentIndex);

    if (reduceMotion) {
      _controller.value = 1;
      setState(() => _outgoingIndex = -1);
      return;
    }
    _controller.forward(from: 0).whenComplete(_onTransitionComplete);
  }

  // Keep the current slide and its two wrap-around neighbours decoded so the
  // incoming image never decodes on the transition frame.
  void _precacheAround(int index) {
    for (final i in {_wrap(index - 1), index, _wrap(index + 1)}) {
      precacheImage(NetworkImage(_slides[i].imageUrl), context);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(CatalogRoutes.home);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dy = event.scrollDelta.dy;
    if (dy.abs() < 1) return;
    _go(dy > 0 ? 1 : -1);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    // Swipe up (negative velocity) reveals the next section.
    _go(velocity < 0 ? 1 : -1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.space) {
      _go(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_outgoingIndex >= 0)
                  RepaintBoundary(
                    child: _StorySection(
                      key: ValueKey('out-$_outgoingIndex'),
                      slide: _slides[_outgoingIndex],
                      progress: _controller,
                      direction: _direction,
                      isIncoming: false,
                      seed: _outgoingIndex,
                    ),
                  ),
                RepaintBoundary(
                  child: _StorySection(
                    key: ValueKey('in-$_currentIndex'),
                    slide: _slides[_currentIndex],
                    progress: _controller,
                    direction: _direction,
                    isIncoming: true,
                    seed: _currentIndex,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _StoryHeader(
                    onClose: _close,
                    index: _currentIndex,
                    count: _slides.length,
                  ),
                ),
                _StoryDots(index: _currentIndex, count: _slides.length),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Timing ──────────────────────────────────────────────────────────────────

const Duration _transitionDuration = Duration(milliseconds: 800);
// Heading letters begin ~0.2/1.25 into the timeline (matching the GSAP offset),
// each rising over [_headingCharSpan] with up to [_headingStagger] of random
// delay between them.
const double _headingStart = 0.16;
const double _headingStagger = 0.34;
const double _headingCharSpan = 0.55;
// Letters start 150% of their own height below (GSAP `yPercent: 150`). The
// per-line clip in [_StorySectionState._animatedHeading] masks that travel so
// they slide up cleanly from the baseline instead of floating in mid-air.
const double _headingCharRise = 1.5;

const LinearGradient _scrim = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0x99000000), Color(0x1A000000)],
  stops: [0.5, 1.0],
);

// ── Data (fixed V1 slides) ───────────────────────────────────────────────────

class _StorySlide {
  final String imageUrl;
  final String heading;

  const _StorySlide({required this.imageUrl, required this.heading});
}

const List<_StorySlide> _slides = [
  _StorySlide(
    imageUrl: 'https://picsum.photos/seed/kiki-story-1/1280/1920',
    heading: 'Scroll down',
  ),
  _StorySlide(
    imageUrl: 'https://picsum.photos/seed/kiki-story-2/1280/1920',
    heading: 'Crafted in motion',
  ),
  _StorySlide(
    imageUrl: 'https://picsum.photos/seed/kiki-story-3/1280/1920',
    heading: 'Layer by layer',
  ),
  _StorySlide(
    imageUrl: 'https://picsum.photos/seed/kiki-story-4/1280/1920',
    heading: 'Depth in every frame',
  ),
  _StorySlide(
    imageUrl: 'https://picsum.photos/seed/kiki-story-5/1280/1920',
    heading: 'Keep scrolling',
  ),
];

// ── One section ──────────────────────────────────────────────────────────────

class _StorySection extends StatefulWidget {
  final _StorySlide slide;
  final Animation<double> progress;
  final int direction;
  final bool isIncoming;

  /// Seeds the per-character stagger so it is stable across rebuilds.
  final int seed;

  const _StorySection({
    super.key,
    required this.slide,
    required this.progress,
    required this.direction,
    required this.isIncoming,
    required this.seed,
  });

  @override
  State<_StorySection> createState() => _StorySectionState();
}

class _StorySectionState extends State<_StorySection> {
  late final List<String> _words = widget.slide.heading.split(' ');
  // One randomised start offset per letter (spaces excluded), resolved once.
  late final List<double> _starts = _resolveStarts();

  List<double> _resolveStarts() {
    final letters = _words.fold<int>(0, (sum, w) => sum + w.length);
    final rng = math.Random(widget.seed);
    return List<double>.generate(
      letters,
      (_) => _headingStart + rng.nextDouble() * _headingStagger,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, _) {
        final t = widget.progress.value;
        final eased = Curves.easeInOut.transform(t);
        final dir = widget.direction;

        if (!widget.isIncoming) {
          // Outgoing: no curtain — the background just drifts away. Render the
          // heading with the *same* per-character widget (fully settled) as the
          // incoming side, otherwise the text would re-layout to a different
          // width the instant a section flips from incoming to outgoing.
          return _background(
            context,
            bgY: -0.15 * dir * eased,
            heading: _animatedHeading(context, 1.0, dir),
          );
        }

        final outerY = (1 - eased) * dir;
        final innerY = -(1 - eased) * dir;
        final bgY = 0.15 * (1 - eased) * dir;
        return ClipRect(
          child: FractionalTranslation(
            translation: Offset(0, outerY),
            child: ClipRect(
              child: FractionalTranslation(
                translation: Offset(0, innerY),
                child: _background(
                  context,
                  bgY: bgY,
                  heading: _animatedHeading(context, t, dir),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _background(
    BuildContext context, {
    required double bgY,
    required Widget heading,
  }) {
    final size = MediaQuery.sizeOf(context);
    // Editorial flush-left on mobile (bolder for big stacked words); centred on
    // wider screens.
    final isMobile = size.width < 600;
    return FractionalTranslation(
      translation: Offset(0, bgY),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Oversized so the ±15% parallax never reveals an edge.
          ClipRect(
            child: OverflowBox(
              maxHeight: size.height * 1.35,
              child: Image(
                image: NetworkImage(widget.slide.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const DecoratedBox(decoration: BoxDecoration(gradient: _scrim)),
          Align(
            alignment: isMobile ? Alignment.centerLeft : Alignment.center,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 28 : 24),
              child: heading,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headingStyle(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Scale the heading harder on narrow screens (and floor it higher) so the
    // title fills the viewport and the per-letter rise reads as boldly as on
    // desktop. Long titles simply wrap to stacked lines, which looks editorial.
    final isMobile = width < 600;
    final fontSize = (width * (isMobile ? 0.135 : 0.085)).clamp(
      isMobile ? 46.0 : 34.0,
      120.0,
    );
    return TextStyle(
      fontFamily: kDrawerFontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      // Matches GSAP's line-height: 1.2; also gives the per-line clip enough
      // room not to shave descenders at rest.
      height: 1.2,
      letterSpacing: -0.5,
      color: Colors.white,
    );
  }

  Widget _animatedHeading(BuildContext context, double t, int dir) {
    final style = _headingStyle(context);
    final fontSize = style.fontSize ?? 40;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final spaceWidth = fontSize * 0.3;
    final rows = <Widget>[];
    var letter = 0;
    for (var w = 0; w < _words.length; w++) {
      final cells = <Widget>[];
      for (final ch in _words[w].split('')) {
        cells.add(_charCell(ch, _starts[letter++], t, dir, style));
      }
      // One ClipRect per word/line = the GSAP `.clip-text { overflow: hidden }`
      // mask: every letter slides up from the same baseline, cleanly.
      rows.add(
        ClipRect(
          child: Row(mainAxisSize: MainAxisSize.min, children: cells),
        ),
      );
      if (w < _words.length - 1) rows.add(SizedBox(width: spaceWidth));
    }
    return Wrap(
      // Flush-left + snug lines on mobile (stacked words read as one editorial
      // block); centred with default leading on desktop.
      alignment: isMobile ? WrapAlignment.start : WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: isMobile ? -fontSize * 0.08 : 0.0,
      children: rows,
    );
  }

  Widget _charCell(
    String ch,
    double start,
    double t,
    int dir,
    TextStyle style,
  ) {
    final end = (start + _headingCharSpan).clamp(0.0, 1.0);
    // GSAP `ease: "power2"` == power2.out == easeOutCubic.
    final local = Interval(
      start,
      end,
      curve: Curves.easeOutCubic,
    ).transform(t.clamp(0.0, 1.0));
    // Fade in while rising from `_headingCharRise` below. The big travel is
    // masked by the per-line ClipRect in [_animatedHeading] (one shared mask
    // for the whole word/line — NOT one per glyph, which reads as sliced).
    return Opacity(
      opacity: local,
      child: FractionalTranslation(
        translation: Offset(0, (1 - local) * _headingCharRise * dir),
        child: Text(ch, style: style),
      ),
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

class _StoryHeader extends StatelessWidget {
  final VoidCallback onClose;
  final int index;
  final int count;

  const _StoryHeader({
    required this.onClose,
    required this.index,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                '${_pad(index + 1)} / ${_pad(count)}',
                style: const TextStyle(
                  fontFamily: kDrawerFontFamily,
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _StoryDots extends StatelessWidget {
  final int index;
  final int count;

  const _StoryDots({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: 6,
                  height: i == index ? 22 : 6,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
