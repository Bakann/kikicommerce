// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'media_crop_data.dart';
import 'optimize_media_upload.dart';

const String _tag = '[hero-canvas]';

Future<OptimizedMediaUpload?> encodeOpaqueJpegWithCanvas({
  required Uint8List sourceBytes,
  required String filename,
  required MediaCropData cropData,
  required int recommendedLongEdge,
  double quality = 0.82,
}) async {
  final stopwatch = Stopwatch()..start();
  String? url;
  try {
    final mime = _inferMime(filename);
    final blob = html.Blob([sourceBytes], mime);
    url = html.Url.createObjectUrlFromBlob(blob);

    final image = html.ImageElement();
    await _waitForImageLoad(image, url);
    final naturalW = image.naturalWidth;
    final naturalH = image.naturalHeight;
    debugPrint(
      '$_tag decoded ${naturalW}x$naturalH src=${sourceBytes.lengthInBytes}B '
      'in ${stopwatch.elapsedMilliseconds}ms',
    );
    if (naturalW <= 0 || naturalH <= 0) {
      debugPrint('$_tag abort: zero natural dimensions');
      return null;
    }

    final srcX = (cropData.x * naturalW).round().clamp(0, naturalW - 1);
    final srcY = (cropData.y * naturalH).round().clamp(0, naturalH - 1);
    final srcW = math
        .max(1, (cropData.width * naturalW).round())
        .clamp(1, naturalW - srcX);
    final srcH = math
        .max(1, (cropData.height * naturalH).round())
        .clamp(1, naturalH - srcY);

    final longest = math.max(srcW, srcH);
    final scale = longest > recommendedLongEdge
        ? recommendedLongEdge / longest
        : 1.0;
    final outW = math.max(1, (srcW * scale).round());
    final outH = math.max(1, (srcH * scale).round());

    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;
    ctx
      ..fillStyle = '#ffffff'
      ..fillRect(0, 0, outW, outH);
    ctx.drawImageScaledFromSource(
      image,
      srcX,
      srcY,
      srcW,
      srcH,
      0,
      0,
      outW,
      outH,
    );
    debugPrint(
      '$_tag drew ${outW}x$outH (crop ${srcW}x$srcH @ $srcX,$srcY) '
      'in ${stopwatch.elapsedMilliseconds}ms',
    );

    final outBlob = await canvas.toBlob('image/jpeg', quality) as html.Blob?;
    if (outBlob == null) {
      debugPrint('$_tag toBlob returned null');
      return null;
    }
    debugPrint(
      '$_tag toBlob ok size=${outBlob.size} type=${outBlob.type} '
      'in ${stopwatch.elapsedMilliseconds}ms',
    );

    final outBytes = await _readBlobAsBytes(outBlob);
    if (outBytes == null) {
      debugPrint('$_tag blob read returned unexpected type');
      return null;
    }
    debugPrint(
      '$_tag done bytes=${outBytes.lengthInBytes} '
      'total=${stopwatch.elapsedMilliseconds}ms',
    );

    return OptimizedMediaUpload(
      fileBytes: outBytes,
      filename: _replaceExtension(filename, 'jpg'),
      mimeType: 'image/jpeg',
      originalBytes: sourceBytes.lengthInBytes,
      wasOptimized: true,
    );
  } catch (e, st) {
    debugPrint('$_tag failed at ${stopwatch.elapsedMilliseconds}ms: $e\n$st');
    return null;
  } finally {
    if (url != null) {
      html.Url.revokeObjectUrl(url);
    }
  }
}

Future<void> _waitForImageLoad(html.ImageElement image, String src) async {
  final completer = Completer<void>();
  StreamSubscription<html.Event>? loadSub;
  StreamSubscription<html.Event>? errorSub;
  loadSub = image.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  errorSub = image.onError.listen((event) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('<img> decode error: $event'));
    }
  });
  image.src = src;
  try {
    await completer.future;
  } finally {
    await loadSub.cancel();
    await errorSub.cancel();
  }
}

Future<Uint8List?> _readBlobAsBytes(html.Blob blob) async {
  final reader = html.FileReader();
  final completer = Completer<void>();
  StreamSubscription<html.Event>? loadSub;
  StreamSubscription<html.Event>? errorSub;
  loadSub = reader.onLoadEnd.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  errorSub = reader.onError.listen((event) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('FileReader error: $event'));
    }
  });
  reader.readAsArrayBuffer(blob);
  try {
    await completer.future;
  } finally {
    await loadSub.cancel();
    await errorSub.cancel();
  }
  final result = reader.result;
  if (result is ByteBuffer) return result.asUint8List();
  if (result is Uint8List) return result;
  if (result is ByteData) return result.buffer.asUint8List();
  if (result is List<int>) return Uint8List.fromList(result);
  return null;
}

String _inferMime(String filename) {
  final n = filename.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.bmp')) return 'image/bmp';
  return 'image/jpeg';
}

String _replaceExtension(String filename, String newExtension) {
  final sanitized = filename.trim();
  final dotIndex = sanitized.lastIndexOf('.');
  final baseName = dotIndex <= 0 ? sanitized : sanitized.substring(0, dotIndex);
  return '$baseName.$newExtension';
}
