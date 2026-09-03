import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GoogleFonts usages stay within bundled local asset variants', () {
    final bundledWeightsByFamily = <String, Set<int>>{
      'cormorantGaramond': {400, 500, 700},
      'notoSerif': {400, 500, 600},
    };
    final expectedAssetsByFamily = <String, Map<int, String>>{
      'cormorantGaramond': {
        400: 'assets/google_fonts/CormorantGaramond-Regular.ttf',
        500: 'assets/google_fonts/CormorantGaramond-Medium.ttf',
        700: 'assets/google_fonts/CormorantGaramond-Bold.ttf',
      },
      'notoSerif': {
        400: 'assets/google_fonts/NotoSerif-Regular.ttf',
        500: 'assets/google_fonts/NotoSerif-Medium.ttf',
        600: 'assets/google_fonts/NotoSerif-SemiBold.ttf',
      },
    };

    for (final familyAssets in expectedAssetsByFamily.values) {
      for (final assetPath in familyAssets.values) {
        expect(File(assetPath).existsSync(), isTrue, reason: assetPath);
      }
    }

    final violations = <String>[];
    final googleFontsCall = RegExp(
      r'GoogleFonts\.([A-Za-z0-9_]+)\s*\(([\s\S]*?)\)',
      multiLine: true,
    );
    final literalWeight = RegExp(r'fontWeight\s*:\s*FontWeight\.w(\d{3})');

    for (final file in _dartFilesUnder('lib')) {
      final source = file.readAsStringSync();
      for (final match in googleFontsCall.allMatches(source)) {
        final family = match.group(1)!;
        if (family == 'pendingFonts') {
          continue;
        }
        final args = match.group(2)!;
        final allowedWeights = bundledWeightsByFamily[family];
        if (allowedWeights == null) {
          violations.add(
            '${file.path}: GoogleFonts.$family has no bundled asset guard',
          );
          continue;
        }

        final weightMatch = literalWeight.firstMatch(args);
        if (weightMatch == null) {
          continue;
        }

        final weight = int.parse(weightMatch.group(1)!);
        if (!allowedWeights.contains(weight)) {
          violations.add(
            '${file.path}: GoogleFonts.$family uses FontWeight.w$weight, '
            'but bundled weights are ${allowedWeights.join(', ')}',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('critical serif fonts are registered as Flutter fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const criticalAssets = [
      'assets/google_fonts/CormorantGaramond-Regular.ttf',
      'assets/google_fonts/CormorantGaramond-Medium.ttf',
    ];

    expect(pubspec, contains('family: CormorantGaramond'));
    for (final asset in criticalAssets) {
      expect(pubspec, contains('asset: $asset'));
    }
  });
}

Iterable<File> _dartFilesUnder(String path) sync* {
  final root = Directory(path);
  if (!root.existsSync()) {
    return;
  }
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    }
  }
}
