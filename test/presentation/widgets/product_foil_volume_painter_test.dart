import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/data/models/product_foil.dart';
import 'package:kiki_commerce/presentation/widgets/product_foil_volume_painter.dart';

Future<ui.Image> _image(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 10), Paint()..color = color);
  return recorder.endRecording().toImage(8, 10);
}

void main() {
  test(
    'particle animation closes its loop without a position or alpha jump',
    () {
      for (var index = 0; index < 12; index++) {
        final start = ProductFoilVolumePainter.particleOrbitOffset(
          index: index,
          progress: 0,
          radius: 10,
        );
        final end = ProductFoilVolumePainter.particleOrbitOffset(
          index: index,
          progress: 1,
          radius: 10,
        );
        expect(end.dx, closeTo(start.dx, 1e-10));
        expect(end.dy, closeTo(start.dy, 1e-10));
        expect(
          ProductFoilVolumePainter.particleTwinkle(index: index, progress: 1),
          closeTo(
            ProductFoilVolumePainter.particleTwinkle(index: index, progress: 0),
            1e-10,
          ),
        );
      }
    },
  );

  testWidgets('volume painter renders the depth and particle paths', (
    tester,
  ) async {
    final source = await _image(const Color(0xFF806040));
    final mask = await _image(Colors.white);
    final background = await _image(const Color(0xFF204060));
    final rim = await _image(const Color(0x80FFFFFF));

    final pointer = ValueNotifier<Offset?>(const Offset(95, 35));
    final tilt = ValueNotifier<Offset?>(null);
    final particleTime = ValueNotifier<double>(0);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      pointer.dispose();
      tilt.dispose();
      particleTime.dispose();
      source.dispose();
      mask.dispose();
      background.dispose();
      rim.dispose();
    });
    final depth = ProductFoilDepthMesh(
      columns: 2,
      rows: 2,
      values: const [-1, 0, 0.5, 1],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 150,
            child: CustomPaint(
              painter: ProductFoilVolumePainter(
                source: source,
                subjectMask: mask,
                background: background,
                rim: rim,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                depthMesh: depth,
                particles: const [
                  ProductFoilParticleSeed(x: 0.5, y: 0.5, brightness: 1),
                ],
                particleTime: particleTime,
                sweep: const AlwaysStoppedAnimation(0.5),
                hover: const AlwaysStoppedAnimation(1),
                pointer: pointer,
                tilt: tilt,
                motionEnabled: true,
                webMobileSafe: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    tilt.value = const Offset(0.2, 0.8);
    particleTime.value = 0.5;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
