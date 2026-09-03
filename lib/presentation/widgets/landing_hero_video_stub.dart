import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LandingHeroVideo extends StatefulWidget {
  final String videoUrl;

  const LandingHeroVideo({super.key, required this.videoUrl});

  @override
  State<LandingHeroVideo> createState() => _LandingHeroVideoState();
}

class _LandingHeroVideoState extends State<LandingHeroVideo> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(covariant LandingHeroVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializeController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeController() async {
    final previousController = _controller;
    _controller = null;
    _error = null;
    if (mounted) {
      setState(() {});
    }

    await previousController?.dispose();

    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        setState(() {
          _error = ArgumentError('Invalid video URL');
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } catch (error) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF1B1B1B));
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
