import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/media_image_support.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../navigation/route_visibility.dart';
import '../providers/drawer_navigation_preloader.dart';
import '../providers/navigation_providers.dart';

class StorefrontDrawerPrefetch extends ConsumerStatefulWidget {
  static const prefetchDelay = Duration(milliseconds: 1800);

  final Widget child;

  const StorefrontDrawerPrefetch({super.key, required this.child});

  @override
  ConsumerState<StorefrontDrawerPrefetch> createState() =>
      _StorefrontDrawerPrefetchState();
}

class _StorefrontDrawerPrefetchState
    extends ConsumerState<StorefrontDrawerPrefetch> {
  static const _maxPromoImagesToPrecache = 6;
  final Set<String> _precachedPromoUrls = <String>{};
  Timer? _prefetchTimer;

  @override
  void initState() {
    super.initState();
    // Trigger the drawer warm-up here (rather than in MainShell) because
    // StorefrontDrawerPrefetch is the only widget mounted on EVERY page
    // that exposes the drawer — including the landing page, which is
    // outside the MainShell's ShellRoute. The preloader is idempotent
    // per ProviderContainer, so triggering from multiple call sites is
    // safe.
    //
    // The call is deferred to the post-frame callback because the
    // preloader synchronously mutates Notifier state, which Riverpod
    // forbids inside widget life-cycle methods. Keep the warm-up outside the
    // cold-start window too: DevTools traces showed PocketBase drawer requests
    // competing with brand/navigation/CMS bootstrap on mobile.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchTimer ??= Timer(StorefrontDrawerPrefetch.prefetchDelay, () {
        _prefetchTimer = null;
        if (!mounted) return;
        if (!isCurrentRoute(context)) return;
        unawaited(_runPrefetch());
      });
    });
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _runPrefetch() async {
    if (!isCurrentRoute(context)) return;
    await ref.read(drawerNavigationPreloaderProvider.notifier).preload();
    if (!mounted || !isCurrentRoute(context)) return;

    final preloadState = ref.read(drawerNavigationPreloaderProvider);
    final hasUsableManagedDrawer =
        preloadState.configStatus == DrawerPreloadStatus.completed &&
        !preloadState.categoriesWereNeeded;
    if (!hasUsableManagedDrawer) {
      return;
    }

    await _prefetchDrawer();
  }

  Future<void> _prefetchDrawer() async {
    final result = await ref.read(mainDrawerNavigationProvider.future);
    if (!mounted) {
      return;
    }

    final urls = _collectPromoImageUrls(
      result,
    ).where(_precachedPromoUrls.add).take(_maxPromoImagesToPrecache);
    for (final url in urls) {
      if (!mounted) {
        return;
      }
      if (isKnownUnsupportedImageFormat(url: url)) {
        continue;
      }
      await precacheImage(
        CachedNetworkImageProvider(url),
        context,
        onError: (_, _) {},
      );
    }
  }
}

Iterable<String> _collectPromoImageUrls(
  DrawerNavigationLoadResult result,
) sync* {
  final normalized = result.normalized;
  if (normalized == null || !normalized.isUsable) {
    return;
  }

  for (final root in normalized.roots) {
    final rootPromoMedia = root.item.promoMedia;
    final template =
        root.item.desktopDrawerTemplate ??
        DrawerNavigationDesktopTemplate.listOnly;
    if (rootPromoMedia != null &&
        template != DrawerNavigationDesktopTemplate.listOnly) {
      yield rootPromoMedia.listingUrl;
    }

    for (final node in _walkNodes(root.children)) {
      if (node.item.placement != DrawerNavigationPlacement.promo) {
        continue;
      }
      final media = node.item.promoMedia;
      if (media != null) {
        yield media.listingUrl;
      }
    }
  }
}

Iterable<DrawerNavigationNode> _walkNodes(
  Iterable<DrawerNavigationNode> nodes,
) sync* {
  for (final node in nodes) {
    yield node;
    yield* _walkNodes(node.children);
  }
}
