import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/cms/cms_models.dart';
import '../../application/navigation/drawer_editorial_tiles.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../providers/catalog_invalidator_provider.dart';
import 'cms/forms/cms_form_fields.dart';
import 'cms/forms/cms_media_slot_field.dart';

class DrawerEditorialTilesEditorDialog extends ConsumerStatefulWidget {
  final String authToken;
  final DrawerNavigationItemData item;

  const DrawerEditorialTilesEditorDialog({
    super.key,
    required this.authToken,
    required this.item,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String authToken,
    required DrawerNavigationItemData item,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          DrawerEditorialTilesEditorDialog(authToken: authToken, item: item),
    );
  }

  @override
  ConsumerState<DrawerEditorialTilesEditorDialog> createState() =>
      _DrawerEditorialTilesEditorDialogState();
}

class _DrawerEditorialTilesEditorDialogState
    extends ConsumerState<DrawerEditorialTilesEditorDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _jsonController;
  late List<_EditableDrawerEditorialTile> _tiles;
  String _layoutMode = 'auto';
  DrawerEditorialTilesResolvedLayout? _forcedLayout;
  String? _validationError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final raw = _rawEditorialTiles(widget.item.config);
    _layoutMode = _readLayoutMode(raw['layout']);
    _forcedLayout = _readForcedLayout(raw['layout']);
    _tiles = _readTiles(raw['items']);
    for (final tile in _tiles) {
      tile.addListener(_clearValidationError);
    }
    _jsonController = TextEditingController(text: _prettyJson(_buildConfig()));
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _jsonController.dispose();
    for (final tile in _tiles) {
      tile.removeListener(_clearValidationError);
      tile.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    if (_tabController.index == 1) {
      _jsonController.text = _prettyJson(_buildConfig());
      _jsonController.selection = TextSelection.collapsed(
        offset: _jsonController.text.length,
      );
      setState(() => _validationError = null);
      return;
    }

    final parsed = _tryParseJson();
    if (parsed == null) {
      _tabController.animateTo(1);
      setState(
        () => _validationError =
            'JSON invalide — corrigez-le avant de revenir au formulaire.',
      );
      return;
    }
    _hydrateFromConfig(parsed);
  }

  void _hydrateFromConfig(Map<String, dynamic> config) {
    final previousTiles = _tiles;
    for (final tile in previousTiles) {
      tile.removeListener(_clearValidationError);
      tile.dispose();
    }
    _layoutMode = _readLayoutMode(config['layout']);
    _forcedLayout = _readForcedLayout(config['layout']);
    _tiles = _readTiles(config['items']);
    for (final tile in _tiles) {
      tile.addListener(_clearValidationError);
    }
    setState(() => _validationError = null);
  }

  void _clearValidationError() {
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  Map<String, dynamic> _buildConfig() {
    return <String, dynamic>{
      'type': drawerEditorialTilesType,
      'layout': <String, dynamic>{
        'mode': _layoutMode,
        'forced': _forcedLayout == null
            ? null
            : drawerEditorialLayoutWireValue(_forcedLayout!),
      },
      'items': _tiles.map((tile) => tile.toJson()).toList(growable: false),
    };
  }

  Map<String, dynamic>? _tryParseJson() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  String _prettyJson(Object data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  void _addTile() {
    final tile = _EditableDrawerEditorialTile(
      title: 'Nouvelle tuile',
      link: '/catalog',
    );
    tile.addListener(_clearValidationError);
    setState(() {
      _tiles.add(tile);
      _validationError = null;
    });
  }

  void _removeTile(int index) {
    final tile = _tiles.removeAt(index);
    tile.removeListener(_clearValidationError);
    tile.dispose();
    setState(() => _validationError = null);
  }

  void _reorderTiles(int oldIndex, int newIndex) {
    final tile = _tiles.removeAt(oldIndex);
    _tiles.insert(newIndex, tile);
    setState(() => _validationError = null);
  }

  void _setTileMedia(int index, CmsMediaRef? media) {
    setState(() {
      _tiles[index].media = media;
      _validationError = null;
    });
  }

  String? _validateConfig(Map<String, dynamic> config) {
    final rawItems = config['items'];
    if (rawItems is! List) {
      return 'Le champ items doit être une liste.';
    }

    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      if (raw is! Map) {
        return 'La tuile ${index + 1} est invalide.';
      }
      final json = Map<String, dynamic>.from(raw);
      if (json['isActive'] == false) {
        continue;
      }
      final title = (json['title'] as String?)?.trim() ?? '';
      final link = (json['link'] as String?)?.trim() ?? '';
      final media = CmsMediaRef.maybeFromJson(json['media']);
      final label = title.isEmpty ? 'Tuile ${index + 1}' : 'La tuile “$title”';
      if (title.isEmpty) {
        return 'La tuile ${index + 1} n’a pas de titre.';
      }
      if (link.isEmpty) {
        return '$label n’a pas de lien.';
      }
      if (media == null || !media.isUsable) {
        return '$label n’a pas d’image.';
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeForSave(Map<String, dynamic> config) {
    final rawItems = config['items'];
    final normalizedItems = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) {
          continue;
        }
        final item = Map<String, dynamic>.from(raw);
        final title = (item['title'] as String?)?.trim() ?? '';
        item['title'] = title;
        item['link'] = (item['link'] as String?)?.trim() ?? '';
        final media = CmsMediaRef.maybeFromJson(item['media']);
        item['media'] = drawerEditorialMediaMap(media, fallbackAlt: title);
        item['isActive'] = item['isActive'] as bool? ?? true;
        normalizedItems.add(item);
      }
    }
    return <String, dynamic>{
      'type': drawerEditorialTilesType,
      'layout': DrawerEditorialTilesLayout.fromJson(config['layout']).toJson(),
      'items': normalizedItems,
    };
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _validationError = null;
    });

    final config = _tabController.index == 1 ? _tryParseJson() : _buildConfig();
    if (config == null) {
      setState(() {
        _saving = false;
        _validationError = 'Le JSON doit être un objet valide.';
      });
      return;
    }

    final validationError = _validateConfig(config);
    if (validationError != null) {
      setState(() {
        _saving = false;
        _validationError = validationError;
      });
      return;
    }

    final normalizedEditorialTiles = _normalizeForSave(config);
    final nextConfig = <String, dynamic>{
      ...widget.item.config,
      drawerEditorialTilesConfigKey: normalizedEditorialTiles,
    };

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: widget.authToken,
        collection: 'navigation_items',
        recordId: widget.item.id,
        data: {'config': nextConfig},
      );
      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
        DrawerNavigationInvalidation(),
      ]);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _validationError = 'Échec de la sauvegarde : $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.9).clamp(360.0, 760.0);
    final height = (size.height * 0.9).clamp(520.0, 780.0);

    return Dialog(
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tiles éditoriales — ${widget.item.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF1B1B1B),
                indicatorColor: const Color(0xFF1B1B1B),
                tabs: const [
                  Tab(text: 'Formulaire'),
                  Tab(text: 'JSON'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_buildFormView(), _buildJsonView()],
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationError!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final activeCount = _tiles.where((tile) => tile.isActive).length;
    final showWarning =
        activeCount != 0 &&
        activeCount != 1 &&
        activeCount != 2 &&
        activeCount != 4;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CmsFormSectionHeader(label: 'Layout'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _layoutMode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mode',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text('Auto recommandé'),
                    ),
                    DropdownMenuItem(value: 'forced', child: Text('Forcé')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _layoutMode = value;
                            _forcedLayout ??=
                                DrawerEditorialTilesResolvedLayout.single;
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    DropdownButtonFormField<
                      DrawerEditorialTilesResolvedLayout?
                    >(
                      initialValue: _forcedLayout,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Layout forcé',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem<DrawerEditorialTilesResolvedLayout?>(
                          value: null,
                          child: Text('Aucun'),
                        ),
                        DropdownMenuItem(
                          value: DrawerEditorialTilesResolvedLayout.single,
                          child: Text('Image unique'),
                        ),
                        DropdownMenuItem(
                          value: DrawerEditorialTilesResolvedLayout.stacked,
                          child: Text('Empilé vertical'),
                        ),
                        DropdownMenuItem(
                          value: DrawerEditorialTilesResolvedLayout.grid2x2,
                          child: Text('Grille 2x2'),
                        ),
                        DropdownMenuItem(
                          value: DrawerEditorialTilesResolvedLayout.adaptive,
                          child: Text('Adaptive'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              setState(() {
                                _forcedLayout = value;
                                _layoutMode = value == null ? 'auto' : 'forced';
                              });
                            },
                    ),
              ),
            ],
          ),
          if (showWarning) ...[
            const SizedBox(height: 10),
            Text(
              '$activeCount tuiles n’est pas une composition recommandée. Utilisez 1, 2 ou 4 tuiles pour un rendu maîtrisé.',
              style: const TextStyle(color: Color(0xFF9A6A00), fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: CmsFormSectionHeader(label: 'Tuiles')),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addTile,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter une tuile'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tiles.isEmpty)
            _EmptyTilesState(onAdd: _addTile)
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tiles.length,
              onReorderItem: _saving ? (_, _) {} : _reorderTiles,
              itemBuilder: (context, index) {
                final tile = _tiles[index];
                return Padding(
                  key: ValueKey(tile.localId),
                  padding: EdgeInsets.only(
                    bottom: index == _tiles.length - 1 ? 0 : 12,
                  ),
                  child: _EditableTileCard(
                    index: index,
                    tile: tile,
                    enabled: !_saving,
                    onRemove: () => _removeTile(index),
                    onActiveChanged: (value) {
                      setState(() {
                        tile.isActive = value;
                        _validationError = null;
                      });
                    },
                    onMediaChanged: (media) => _setTileMedia(index, media),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildJsonView() {
    return TextField(
      controller: _jsonController,
      enabled: !_saving,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.4,
      ),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.all(12),
      ),
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\t'))],
    );
  }
}

class _EditableDrawerEditorialTile {
  static int _nextLocalId = 0;

  final int localId;
  final TextEditingController title;
  final TextEditingController link;
  CmsMediaRef? media;
  bool isActive;

  _EditableDrawerEditorialTile({
    required String title,
    required String link,
    this.media,
    this.isActive = true,
  }) : localId = _nextLocalId++,
       title = TextEditingController(text: title),
       link = TextEditingController(text: link);

  factory _EditableDrawerEditorialTile.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _EditableDrawerEditorialTile(
      title: cmsStringValue(json['title']),
      link: cmsStringValue(json['link']),
      media: CmsMediaRef.maybeFromJson(json['media']),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  void addListener(VoidCallback listener) {
    title.addListener(listener);
    link.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    title.removeListener(listener);
    link.removeListener(listener);
  }

  void dispose() {
    title.dispose();
    link.dispose();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title.text.trim(),
      'link': link.text.trim(),
      'media': drawerEditorialMediaMap(media, fallbackAlt: title.text),
      'isActive': isActive,
    };
  }
}

class _EditableTileCard extends StatelessWidget {
  final int index;
  final _EditableDrawerEditorialTile tile;
  final bool enabled;
  final VoidCallback onRemove;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<CmsMediaRef?> onMediaChanged;

  const _EditableTileCard({
    required this.index,
    required this.tile,
    required this.enabled,
    required this.onRemove,
    required this.onActiveChanged,
    required this.onMediaChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = tile.title.text.trim().isEmpty
        ? 'Tuile ${index + 1}'
        : tile.title.text.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E0D8)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.drag_handle, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(
                  value: tile.isActive,
                  onChanged: enabled ? onActiveChanged : null,
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tile.title,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Titre affiché *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tile.link,
              enabled: enabled,
              decoration: const InputDecoration(
                labelText: 'Lien cible *',
                hintText: '/fashion/mode-femme/sacs',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            CmsMediaSlotField(
              label: 'Image *',
              value: tile.media,
              onChanged: enabled ? onMediaChanged : (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTilesState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyTilesState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F2),
        border: Border.all(color: const Color(0xFFDADAD2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          const Icon(Icons.dashboard_customize_outlined),
          const SizedBox(height: 8),
          const Text(
            'Aucune tuile éditoriale',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une tuile'),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _rawEditorialTiles(Map<String, dynamic> config) {
  final raw = config[drawerEditorialTilesConfigKey];
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{
    'type': drawerEditorialTilesType,
    'layout': const {'mode': 'auto', 'forced': null},
    'items': const [],
  };
}

String _readLayoutMode(Object? raw) {
  if (raw is! Map) {
    return 'auto';
  }
  final mode = raw['mode'] as String?;
  return mode?.trim().isNotEmpty == true ? mode!.trim() : 'auto';
}

DrawerEditorialTilesResolvedLayout? _readForcedLayout(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  return DrawerEditorialTilesLayout.fromJson(raw).forced;
}

List<_EditableDrawerEditorialTile> _readTiles(Object? raw) {
  if (raw is! List) {
    return <_EditableDrawerEditorialTile>[];
  }
  return raw
      .whereType<Map>()
      .map(_EditableDrawerEditorialTile.fromJson)
      .toList(growable: true);
}
