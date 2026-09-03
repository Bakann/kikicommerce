import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StorefrontShellMode { normal, immersive }

class StorefrontShellState {
  final StorefrontShellMode mode;
  final Color? headerForegroundColor;
  final double? heroHeight;

  const StorefrontShellState({
    this.mode = StorefrontShellMode.normal,
    this.headerForegroundColor,
    this.heroHeight,
  });

  bool get isImmersive => mode == StorefrontShellMode.immersive;
}

class StorefrontShellNotifier extends Notifier<StorefrontShellState> {
  @override
  StorefrontShellState build() => const StorefrontShellState();

  void setImmersive({
    Color foregroundColor = Colors.white,
    double? heroHeight,
  }) {
    if (state.mode == StorefrontShellMode.immersive &&
        state.headerForegroundColor == foregroundColor &&
        state.heroHeight == heroHeight) {
      return;
    }
    state = StorefrontShellState(
      mode: StorefrontShellMode.immersive,
      headerForegroundColor: foregroundColor,
      heroHeight: heroHeight,
    );
  }

  void setNormal() {
    if (state.mode == StorefrontShellMode.normal &&
        state.headerForegroundColor == null &&
        state.heroHeight == null) {
      return;
    }
    state = const StorefrontShellState();
  }

  void setNormalDeferred() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) {
        return;
      }
      setNormal();
    });
  }
}

final storefrontShellProvider =
    NotifierProvider<StorefrontShellNotifier, StorefrontShellState>(() {
      return StorefrontShellNotifier();
    });
