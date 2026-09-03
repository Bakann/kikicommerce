/// Heuristic for the benign rejection that `HTMLMediaElement.play()` emits when
/// the element is paused or detached before playback starts — e.g. a hero is
/// unmounted within a frame or two of mounting during a theme swipe.
///
/// Kept free of `dart:html` so the classification is unit-testable on the VM
/// (the web widget adds a typed `DomException` check on top of this).
bool looksLikeVideoAbortError(Object error) {
  final message = error.toString();
  return message.contains('AbortError') ||
      message.contains('The play() request was interrupted');
}
