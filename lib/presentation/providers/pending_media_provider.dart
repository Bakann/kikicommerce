import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingMediaEntry {
  final Uint8List bytes;
  final int version;

  const PendingMediaEntry({required this.bytes, required this.version});
}

class PendingMediaNotifier extends Notifier<Map<String, PendingMediaEntry>> {
  @override
  Map<String, PendingMediaEntry> build() => const {};

  int set(String mediaId, Uint8List bytes) {
    final nextVersion = (state[mediaId]?.version ?? 0) + 1;
    state = {
      ...state,
      mediaId: PendingMediaEntry(bytes: bytes, version: nextVersion),
    };
    return nextVersion;
  }

  void clear(String mediaId, int version) {
    final current = state[mediaId];
    if (current == null || current.version != version) {
      return;
    }

    final nextState = Map<String, PendingMediaEntry>.from(state);
    nextState.remove(mediaId);
    state = nextState;
  }
}

final pendingMediaProvider =
    NotifierProvider<PendingMediaNotifier, Map<String, PendingMediaEntry>>(
      PendingMediaNotifier.new,
    );

final pendingMediaForProvider = Provider.family<PendingMediaEntry?, String>((
  ref,
  mediaId,
) {
  return ref.watch(pendingMediaProvider.select((state) => state[mediaId]));
});
