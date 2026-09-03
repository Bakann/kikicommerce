import '../cms/cms_models.dart';

const drawerEditorialTilesType = 'drawer_editorial_tiles';
const drawerEditorialTilesConfigKey = 'editorialTiles';

enum DrawerEditorialTilesResolvedLayout { single, stacked, grid2x2, adaptive }

class DrawerEditorialTilesLayout {
  final String mode;
  final DrawerEditorialTilesResolvedLayout? forced;

  const DrawerEditorialTilesLayout({this.mode = 'auto', this.forced});

  factory DrawerEditorialTilesLayout.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DrawerEditorialTilesLayout();
    }
    final json = Map<String, dynamic>.from(raw);
    return DrawerEditorialTilesLayout(
      mode: _normalizeMode(json['mode']),
      forced: _parseResolvedLayout(json['forced']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mode': mode,
      'forced': forced == null ? null : drawerEditorialLayoutWireValue(forced!),
    };
  }
}

class DrawerEditorialTile {
  final String title;
  final String link;
  final CmsMediaRef media;
  final bool isActive;

  const DrawerEditorialTile({
    required this.title,
    required this.link,
    required this.media,
    this.isActive = true,
  });

  bool get isExternalLink {
    final normalized = link.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  factory DrawerEditorialTile.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim() ?? '';
    final link = (json['link'] as String?)?.trim() ?? '';
    final media = CmsMediaRef.maybeFromJson(json['media']);
    if (title.isEmpty || link.isEmpty || media == null || !media.isUsable) {
      throw const FormatException('Invalid drawer editorial tile');
    }
    return DrawerEditorialTile(
      title: title,
      link: link,
      media: media,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'link': link,
      'media': drawerEditorialMediaMap(media, fallbackAlt: title),
      'isActive': isActive,
    };
  }
}

class DrawerEditorialTilesConfig {
  final String type;
  final DrawerEditorialTilesLayout layout;
  final List<DrawerEditorialTile> activeTiles;

  const DrawerEditorialTilesConfig({
    this.type = drawerEditorialTilesType,
    this.layout = const DrawerEditorialTilesLayout(),
    this.activeTiles = const [],
  });

  factory DrawerEditorialTilesConfig.fromJson(Object? raw) {
    if (raw is! Map) {
      return const DrawerEditorialTilesConfig();
    }
    final json = Map<String, dynamic>.from(raw);
    final rawItems = json['items'];
    final items = <DrawerEditorialTile>[];
    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }
        try {
          final tile = DrawerEditorialTile.fromJson(
            Map<String, dynamic>.from(rawItem),
          );
          if (tile.isActive) {
            items.add(tile);
          }
        } on FormatException {
          continue;
        }
      }
    }

    return DrawerEditorialTilesConfig(
      type: (json['type'] as String?)?.trim().isNotEmpty == true
          ? (json['type'] as String).trim()
          : drawerEditorialTilesType,
      layout: DrawerEditorialTilesLayout.fromJson(json['layout']),
      activeTiles: List.unmodifiable(items),
    );
  }

  bool get hasActiveItems => activeTiles.isNotEmpty;

  DrawerEditorialTilesResolvedLayout get resolvedLayout =>
      resolveDrawerEditorialTilesLayout(activeTiles.length, layout);
}

DrawerEditorialTilesResolvedLayout resolveDrawerEditorialTilesLayout(
  int activeTileCount,
  DrawerEditorialTilesLayout layout,
) {
  if (layout.forced != null) {
    return layout.forced!;
  }
  return switch (activeTileCount) {
    1 => DrawerEditorialTilesResolvedLayout.single,
    2 => DrawerEditorialTilesResolvedLayout.stacked,
    4 => DrawerEditorialTilesResolvedLayout.grid2x2,
    _ => DrawerEditorialTilesResolvedLayout.adaptive,
  };
}

Map<String, dynamic>? drawerEditorialMediaMap(
  CmsMediaRef? ref, {
  required String fallbackAlt,
}) {
  if (ref == null) return null;
  final alt = ref.alt?.trim();
  return <String, dynamic>{
    'recordId': ref.recordId,
    'collectionId': ref.collectionId,
    'filename': ref.filename,
    'alt': alt == null || alt.isEmpty ? fallbackAlt.trim() : alt,
  };
}

String drawerEditorialLayoutWireValue(
  DrawerEditorialTilesResolvedLayout layout,
) {
  return switch (layout) {
    DrawerEditorialTilesResolvedLayout.single => 'single',
    DrawerEditorialTilesResolvedLayout.stacked => 'stacked',
    DrawerEditorialTilesResolvedLayout.grid2x2 => 'grid_2x2',
    DrawerEditorialTilesResolvedLayout.adaptive => 'adaptive',
  };
}

DrawerEditorialTilesResolvedLayout? _parseResolvedLayout(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  return switch (value) {
    'single' => DrawerEditorialTilesResolvedLayout.single,
    'stacked' => DrawerEditorialTilesResolvedLayout.stacked,
    'grid_2x2' => DrawerEditorialTilesResolvedLayout.grid2x2,
    'adaptive' => DrawerEditorialTilesResolvedLayout.adaptive,
    _ => null,
  };
}

String _normalizeMode(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  return value.isEmpty ? 'auto' : value;
}
