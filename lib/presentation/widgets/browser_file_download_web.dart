// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> downloadTextFile({
  required String filename,
  required String content,
  required String mimeType,
  bool includeBom = false,
}) async {
  final payload = includeBom ? '\uFEFF$content' : content;
  final blob = html.Blob([payload], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
