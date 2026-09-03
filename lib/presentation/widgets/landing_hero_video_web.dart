// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import 'landing_hero_video_error.dart';

class LandingHeroVideo extends StatefulWidget {
  final String videoUrl;

  const LandingHeroVideo({super.key, required this.videoUrl});

  @override
  State<LandingHeroVideo> createState() => _LandingHeroVideoState();
}

class _LandingHeroVideoState extends State<LandingHeroVideo> {
  static int _nextViewId = 0;

  late final String _viewType = 'landing-hero-video-${_nextViewId++}';
  late final html.VideoElement _videoElement = html.VideoElement()
    ..autoplay = true
    ..loop = true
    ..muted = true
    ..controls = false
    ..setAttribute('playsinline', 'true')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'cover'
    ..style.display = 'block'
    ..style.backgroundColor = '#1B1B1B';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _videoElement,
    );
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant LandingHeroVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _syncVideo();
    }
  }

  @override
  void dispose() {
    _videoElement
      ..pause()
      ..removeAttribute('src')
      ..load();
    super.dispose();
  }

  // play() rejects with AbortError when the element is paused/detached before
  // it resolves (hero unmounted mid theme-swipe). On web the rejection isn't
  // always surfaced as a typed DomException, so fall back to a string check.
  bool _isAbortError(Object error) {
    if (error is html.DomException && error.name == 'AbortError') return true;
    return looksLikeVideoAbortError(error);
  }

  void _syncVideo() {
    _videoElement
      ..src = widget.videoUrl
      ..load();
    // Swallow only the expected AbortError; report anything else (broken URL,
    // CORS, codec) so it stays visible in release telemetry — without crashing,
    // since the video is decorative. (See https://goo.gl/LdLk22)
    unawaited(
      _videoElement.play().catchError((Object error, StackTrace stackTrace) {
        if (_isAbortError(error)) return;
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'landing hero video',
            context: ErrorDescription(
              'while playing landing hero video: ${widget.videoUrl}',
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
