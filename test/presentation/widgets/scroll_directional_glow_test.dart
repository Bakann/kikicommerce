import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/scroll_directional_glow.dart';

void main() {
  testWidgets('directional glow fragment shader compiles and instantiates', (
    tester,
  ) async {
    ui.FragmentProgram? program;
    await tester.runAsync(() async {
      program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/directional_glow.frag',
      );
    });
    expect(program, isNotNull);
    // Instantiating a shader proves the GLSL compiled without errors.
    expect(program!.fragmentShader(), isNotNull);
  });

  testWidgets('reduce motion paints the child directly without the shader', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(child: ScrollDirectionalGlow(child: Text('Homme'))),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedSampler), findsNothing);
    expect(find.text('Homme'), findsOneWidget);
  });
}
