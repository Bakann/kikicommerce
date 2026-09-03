import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';
import 'package:kiki_commerce/presentation/widgets/photo_upload_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoUploadDialog zoom controls', () {
    testWidgets('uses a max-height initial crop frame for preset-based crops', (
      tester,
    ) async {
      final imageBytes = _buildImageBytes();
      final media = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/current.png',
        originalUrl: 'https://example.com/original.png',
        previewUrl: 'https://example.com/preview.png',
      );

      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: PhotoUploadDialog(
                  currentMedia: media,
                  currentMediaId: media.id,
                  authToken: 'token',
                ),
              ),
            ),
          );

          // ui.decodeImageFromList is a native callback that needs real async
          // processing to fire; pumpAndSettle alone cannot drive it.
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 500)),
          );
          await tester.pump();

          final crop = tester.widget<Crop>(find.byType(Crop));
          final builder =
              crop.initialRectBuilder as WithSizeAndRatioInitialRectBuilder;

          expect(builder.size, 1);
          expect(builder.aspectRatio, productDetailMobileHeroAspectRatio);
        },
        () {
          return MockClient((request) async {
            return http.Response.bytes(imageBytes, 200);
          });
        },
      );
    });

    testWidgets(
      'disables zoom-out at minimum scale and zoom-in at maximum scale',
      (tester) async {
        final imageBytes = _buildImageBytes();
        final media = CatalogMedia(
          id: 'media-1',
          url: 'https://example.com/current.png',
          originalUrl: 'https://example.com/original.png',
          previewUrl: 'https://example.com/preview.png',
        );

        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: PhotoUploadDialog(
                    currentMedia: media,
                    currentMediaId: media.id,
                    authToken: 'token',
                  ),
                ),
              ),
            );

            // ui.decodeImageFromList is a native callback that needs real async
            // processing to fire; pumpAndSettle alone cannot drive it.
            await tester.runAsync(
              () => Future.delayed(const Duration(milliseconds: 500)),
            );
            await tester.pump();

            final crop = tester.widget<Crop>(find.byType(Crop));
            final zoomOutFinder = find.widgetWithText(OutlinedButton, 'Zoom -');
            final zoomInFinder = find.widgetWithText(OutlinedButton, 'Zoom +');

            crop.onScaleChanged?.call(1.6, 1.0);
            await tester.pump();

            expect(find.text('Zoom 32% de la plage'), findsOneWidget);
            expect(
              tester.widget<OutlinedButton>(zoomOutFinder).onPressed,
              isNotNull,
            );
            expect(
              tester.widget<OutlinedButton>(zoomInFinder).onPressed,
              isNotNull,
            );

            crop.onScaleChanged?.call(1.0, 1.0);
            await tester.pump();

            expect(find.text('Zoom minimum atteint'), findsOneWidget);
            expect(
              tester.widget<OutlinedButton>(zoomOutFinder).onPressed,
              isNull,
            );
            expect(
              tester.widget<OutlinedButton>(zoomInFinder).onPressed,
              isNotNull,
            );

            crop.onScaleChanged?.call(5.0, 1.0);
            await tester.pump();

            expect(find.text('Zoom maximum atteint'), findsOneWidget);
            expect(
              tester.widget<OutlinedButton>(zoomOutFinder).onPressed,
              isNotNull,
            );
            expect(
              tester.widget<OutlinedButton>(zoomInFinder).onPressed,
              isNull,
            );
          },
          () {
            return MockClient((request) async {
              return http.Response.bytes(imageBytes, 200);
            });
          },
        );
      },
    );
  });

  testWidgets('Crop emits updated image-based rect when zoom changes', (
    tester,
  ) async {
    final controller = CropController();
    final imageBytes = _buildImageBytes();
    final movedRects = <Rect>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 420,
            child: Crop(
              image: imageBytes,
              controller: controller,
              onCropped: (_) {},
              aspectRatio: 1,
              initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                size: 1,
                aspectRatio: 1,
              ),
              precomputedImageSize: const Size(480, 720),
              interactive: true,
              fixCropRect: true,
              onMoved: (_, imageBasedRect) => movedRects.add(imageBasedRect),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(movedRects, isNotEmpty);
    final initialRect = movedRects.last;

    controller.addScale(0.5);
    await tester.pump();

    expect(movedRects.length, greaterThan(1));
    final zoomedRect = movedRects.last;
    expect(zoomedRect.width, lessThan(initialRect.width));
    expect(zoomedRect.height, lessThan(initialRect.height));
  });
}

Uint8List _buildImageBytes() {
  final image = img.Image(width: 480, height: 720);
  img.fill(image, color: img.ColorRgb8(180, 205, 240));
  return Uint8List.fromList(img.encodePng(image));
}
