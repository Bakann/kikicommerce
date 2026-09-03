import '../../domain/catalog/catalog_entities.dart';

List<CatalogMedia> dedupeCatalogMediaById(Iterable<CatalogMedia> media) {
  final seen = <String>{};
  return media.where((item) => seen.add(item.id)).toList();
}

bool shouldEnableNarrative({
  required List<CatalogMedia> uniqueMedia,
  required List<NarrativeChapter> chapters,
}) {
  if (uniqueMedia.length < 2) {
    return false;
  }

  final mediaIds = uniqueMedia.map((media) => media.id).toSet();
  final relevantChapters = chapters
      .where((chapter) => mediaIds.contains(chapter.mediaId))
      .toList();
  final coveredIds = relevantChapters.map((chapter) => chapter.mediaId).toSet();

  if (relevantChapters.length != coveredIds.length) {
    return false;
  }

  return coveredIds.length == mediaIds.length;
}

class NarrativeViewportSample {
  final int index;
  final double top;
  final double bottom;

  const NarrativeViewportSample({
    required this.index,
    required this.top,
    required this.bottom,
  });

  double get center => (top + bottom) / 2;

  bool contains(double anchorY) => top <= anchorY && bottom >= anchorY;
}

int resolveNarrativeActiveIndex({
  required List<NarrativeViewportSample> samples,
  required double anchorY,
}) {
  if (samples.isEmpty) {
    return 0;
  }

  final containingSamples = samples.where((sample) => sample.contains(anchorY));
  final inView = containingSamples.isNotEmpty ? containingSamples : samples;

  NarrativeViewportSample bestSample = inView.first;
  double bestDistance = (bestSample.center - anchorY).abs();

  for (final sample in inView.skip(1)) {
    final distance = (sample.center - anchorY).abs();
    final isBetterTieBreak =
        distance == bestDistance &&
        bestSample.center < anchorY &&
        sample.center >= anchorY;
    if (distance < bestDistance || isBetterTieBreak) {
      bestSample = sample;
      bestDistance = distance;
    }
  }

  return bestSample.index;
}
