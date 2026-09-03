import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

class CategoryTilesForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const CategoryTilesForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CategoryTilesForm> createState() => _CategoryTilesFormState();
}

class _CategoryTilesFormState extends State<CategoryTilesForm> {
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late int _columnsMobile;
  late int _columnsDesktop;
  late List<_EditableCategoryTile> _tiles;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant CategoryTilesForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    _title = TextEditingController(text: cmsStringValue(config['title']));
    _subtitle = TextEditingController(text: cmsStringValue(config['subtitle']));
    _title.addListener(_emit);
    _subtitle.addListener(_emit);
    _columnsMobile = cmsNormalizeColumns(config['columnsMobile'], 2);
    _columnsDesktop = cmsNormalizeColumns(config['columnsDesktop'], 4);
    _tiles = cmsListValue(config['tiles'])
        .whereType<Map>()
        .map((tile) {
          final editable = _EditableCategoryTile.fromJson(tile);
          editable.addListener(_emit);
          return editable;
        })
        .toList(growable: true);
  }

  void _disposeControllers() {
    _title.removeListener(_emit);
    _subtitle.removeListener(_emit);
    _title.dispose();
    _subtitle.dispose();
    for (final tile in _tiles) {
      tile.removeListener(_emit);
      tile.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Map<String, dynamic> _buildConfig() {
    return <String, dynamic>{
      'title': cmsTrimToNull(_title.text),
      'subtitle': cmsTrimToNull(_subtitle.text),
      'columnsMobile': _columnsMobile,
      'columnsDesktop': _columnsDesktop,
      'tiles': _tiles.map((tile) => tile.toJson()).toList(growable: false),
    };
  }

  void _emit() {
    widget.onChanged(_buildConfig());
  }

  void _addTile() {
    final tile = _EditableCategoryTile(
      label: 'Nouvelle tuile',
      href: '/catalog',
    );
    tile.addListener(_emit);
    setState(() => _tiles.add(tile));
    _emit();
  }

  void _duplicateTile(int index) {
    final tile = _tiles[index].clone();
    tile.addListener(_emit);
    setState(() => _tiles.insert(index + 1, tile));
    _emit();
  }

  void _removeTile(int index) {
    final tile = _tiles.removeAt(index);
    tile.removeListener(_emit);
    tile.dispose();
    setState(() {});
    _emit();
  }

  void _moveTile(int from, int to) {
    if (to < 0 || to >= _tiles.length) return;
    final tile = _tiles.removeAt(from);
    _tiles.insert(to, tile);
    setState(() {});
    _emit();
  }

  void _setTileMedia(int index, CmsMediaRef? media) {
    setState(() => _tiles[index].media = media);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CmsFormSectionHeader(label: 'Texte'),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(
                  labelText: 'Sous-titre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Grille'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ColumnCountDropdown(
                      label: 'Colonnes mobile',
                      value: _columnsMobile,
                      onChanged: (value) {
                        setState(() => _columnsMobile = value);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ColumnCountDropdown(
                      label: 'Colonnes desktop',
                      value: _columnsDesktop,
                      onChanged: (value) {
                        setState(() => _columnsDesktop = value);
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: CmsFormSectionHeader(label: 'Tuiles')),
                  OutlinedButton.icon(
                    onPressed: _addTile,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une tuile'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_tiles.isEmpty)
                _EmptyTilesState(onAdd: _addTile)
              else
                for (var index = 0; index < _tiles.length; index++) ...[
                  _CategoryTileEditorCard(
                    key: ValueKey(_tiles[index].id),
                    index: index,
                    tile: _tiles[index],
                    canMoveUp: index > 0,
                    canMoveDown: index < _tiles.length - 1,
                    onMoveUp: () => _moveTile(index, index - 1),
                    onMoveDown: () => _moveTile(index, index + 1),
                    onDuplicate: () => _duplicateTile(index),
                    onRemove: () => _removeTile(index),
                    onMediaChanged: (media) => _setTileMedia(index, media),
                  ),
                  if (index < _tiles.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableCategoryTile {
  static int _nextId = 0;

  final int id;
  final TextEditingController eyebrow;
  final TextEditingController label;
  final TextEditingController href;
  CmsMediaRef? media;

  _EditableCategoryTile({
    String? eyebrow,
    required String label,
    required String href,
    this.media,
  }) : id = _nextId++,
       eyebrow = TextEditingController(text: eyebrow ?? ''),
       label = TextEditingController(text: label),
       href = TextEditingController(text: href);

  factory _EditableCategoryTile.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _EditableCategoryTile(
      eyebrow: cmsStringValue(json['eyebrow']),
      label: cmsStringValue(json['label']),
      href: cmsStringValue(json['href']),
      media: CmsMediaRef.maybeFromJson(json['media']),
    );
  }

  _EditableCategoryTile clone() {
    return _EditableCategoryTile(
      eyebrow: eyebrow.text,
      label: label.text,
      href: href.text,
      media: media,
    );
  }

  void addListener(VoidCallback listener) {
    eyebrow.addListener(listener);
    label.addListener(listener);
    href.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    eyebrow.removeListener(listener);
    label.removeListener(listener);
    href.removeListener(listener);
  }

  void dispose() {
    eyebrow.dispose();
    label.dispose();
    href.dispose();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'eyebrow': cmsTrimToNull(eyebrow.text),
      'label': label.text.trim(),
      'href': href.text.trim(),
      'media': cmsMediaMap(media),
    };
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
          const Icon(Icons.grid_view_outlined, color: Color(0xFF6F6F6F)),
          const SizedBox(height: 8),
          const Text(
            'Aucune tuile',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ajoutez des entrées métier comme Sacs, Accessoires ou Nouveautés.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
          ),
          const SizedBox(height: 12),
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

class _CategoryTileEditorCard extends StatelessWidget {
  final int index;
  final _EditableCategoryTile tile;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final ValueChanged<CmsMediaRef?> onMediaChanged;

  const _CategoryTileEditorCard({
    super.key,
    required this.index,
    required this.tile,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onRemove,
    required this.onMediaChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = tile.label.text.trim().isEmpty
        ? 'Tuile ${index + 1}'
        : 'Tile — ${tile.label.text.trim()}';
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
                _TileActionButton(
                  icon: Icons.arrow_upward,
                  tooltip: 'Monter',
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
                _TileActionButton(
                  icon: Icons.arrow_downward,
                  tooltip: 'Descendre',
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
                _TileActionButton(
                  icon: Icons.content_copy_outlined,
                  tooltip: 'Dupliquer',
                  onPressed: onDuplicate,
                ),
                _TileActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Supprimer',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tile.label,
              decoration: const InputDecoration(
                labelText: 'Libellé *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tile.eyebrow,
              decoration: const InputDecoration(
                labelText: 'Eyebrow',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tile.href,
              decoration: const InputDecoration(
                labelText: 'Lien *',
                hintText: '/category/bags',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            CmsMediaSlotField(
              label: 'Média',
              value: tile.media,
              onChanged: onMediaChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TileActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _TileActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}

class _ColumnCountDropdown extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _ColumnCountDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value < 1 ? 1 : (value > 6 ? 6 : value);
    return DropdownButtonFormField<int>(
      initialValue: normalizedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (var count = 1; count <= 6; count++)
          DropdownMenuItem(value: count, child: Text('$count')),
      ],
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}
