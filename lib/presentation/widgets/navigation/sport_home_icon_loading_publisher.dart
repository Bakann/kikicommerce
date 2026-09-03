import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;

import '../../providers/sport_home_icon_loading_provider.dart';

/// Publishes whether the persistent Sport bottom-nav Home glyph should show
/// its loading animation while this route child is visible.
class SportHomeIconLoadingPublisher extends ConsumerStatefulWidget {
  final bool isLoading;
  final Widget child;

  const SportHomeIconLoadingPublisher({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  ConsumerState<SportHomeIconLoadingPublisher> createState() =>
      _SportHomeIconLoadingPublisherState();
}

class _SportHomeIconLoadingPublisherState
    extends ConsumerState<SportHomeIconLoadingPublisher> {
  legacy.StateController<bool>? _controller;
  bool? _lastPublished;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(sportHomeIconLoadingProvider.notifier);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (_lastPublished != null && controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.mounted) {
          controller.state = false;
        }
      });
    }
    super.dispose();
  }

  void _publish(bool isLoading) {
    if (_lastPublished == isLoading) return;
    _lastPublished = isLoading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastPublished != isLoading) return;
      _controller?.state = isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    _publish(widget.isLoading);
    return widget.child;
  }
}
