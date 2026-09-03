import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

/// Display styles for the carousel; mirrors
/// [HorizontalTileCarouselConfig.layout].
const List<String> kHorizontalTileCarouselLayouts = ['tiles', 'feature'];

String _carouselLayoutLabel(String layout) => switch (layout) {
  'feature' => 'Grandes cartes',
  _ => 'Tuiles',
};

/// Structured editor for `horizontal_tile_carousel` section configs.
///
/// Mirrors [CategoryTilesForm] in shape and ergonomics so admins get the
/// same affordances on both tile-based sections. The JSON tab in
/// [CmsSectionEditorDialog] still exposes the raw config; this form is
/// just a friendlier view onto the same payload.
///
/// Config keys are kept identical to what the Nike seeds and the
/// `HorizontalTileCarouselConfig` parser emit/expect:
///   - `schemaVersion`
///   - `title`
///   - `items: [{ label, href, media? }]`
///
/// No new keys are added so existing seeded sections stay round-trippable.
class HorizontalTileCarouselForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const HorizontalTileCarouselForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<HorizontalTileCarouselForm> createState() =>
      _HorizontalTileCarouselFormState();
}

class _HorizontalTileCarouselFormState
    extends State<HorizontalTileCarouselForm> {
  late TextEditingController _title;
  late int _schemaVersion;
  late String _layout;
  late List<_EditableCarouselItem> _items;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant HorizontalTileCarouselForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    _title = TextEditingController(text: cmsStringValue(config['title']));
    _title.addListener(_emit);
    final rawVersion = config['schemaVersion'];
    _schemaVersion = rawVersion is num ? rawVersion.toInt() : 1;
    _layout = cmsNormalizeOption(
      config['layout'],
      kHorizontalTileCarouselLayouts,
      'tiles',
    );
    _items = cmsListValue(config['items'])
        .whereType<Map>()
        .map((item) {
          final editable = _EditableCarouselItem.fromJson(item);
          editable.addListener(_emit);
          return editable;
        })
        .toList(growable: true);
  }

  void _disposeControllers() {
    _title.removeListener(_emit);
    _title.dispose();
    for (final item in _items) {
      item.removeListener(_emit);
      item.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Map<String, dynamic> _buildConfig() {
    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'title': cmsTrimToNull(_title.text),
      'layout': _layout,
      'items': _items.map((item) => item.toJson()).toList(growable: false),
    };
  }

  void _emit() {
    widget.onChanged(_buildConfig());
  }

  void _addItem() {
    final item = _EditableCarouselItem(
      label: 'Nouvelle tuile',
      href: '/catalog',
    );
    item.addListener(_emit);
    setState(() => _items.add(item));
    _emit();
  }

  void _duplicateItem(int index) {
    final item = _items[index].clone();
    item.addListener(_emit);
    setState(() => _items.insert(index + 1, item));
    _emit();
  }

  void _removeItem(int index) {
    final item = _items.removeAt(index);
    item.removeListener(_emit);
    item.dispose();
    setState(() {});
    _emit();
  }

  void _moveItem(int from, int to) {
    if (to < 0 || to >= _items.length) return;
    final item = _items.removeAt(from);
    _items.insert(to, item);
    setState(() {});
    _emit();
  }

  void _setItemMedia(int index, CmsMediaRef? media) {
    setState(() => _items[index].media = media);
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _layout,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mise en page',
                  helperText:
                      'Tuiles : petites tuiles carrées. '
                      'Grandes cartes : cartes pleine largeur avec titre '
                      'superposé.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final value in kHorizontalTileCarouselLayouts)
                    DropdownMenuItem(
                      value: value,
                      child: Text(_carouselLayoutLabel(value)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _layout = value);
                  _emit();
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: CmsFormSectionHeader(label: 'Tuiles')),
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter une tuile'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                _EmptyItemsState(onAdd: _addItem)
              else
                for (var index = 0; index < _items.length; index++) ...[
                  _CarouselItemEditorCard(
                    key: ValueKey(_items[index].id),
                    index: index,
                    item: _items[index],
                    canMoveUp: index > 0,
                    canMoveDown: index < _items.length - 1,
                    onMoveUp: () => _moveItem(index, index - 1),
                    onMoveDown: () => _moveItem(index, index + 1),
                    onDuplicate: () => _duplicateItem(index),
                    onRemove: () => _removeItem(index),
                    onMediaChanged: (media) => _setItemMedia(index, media),
                  ),
                  if (index < _items.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableCarouselItem {
  static int _nextId = 0;

  final int id;
  final TextEditingController label;
  final TextEditingController href;
  CmsMediaRef? media;

  _EditableCarouselItem({
    required String label,
    required String href,
    this.media,
  }) : id = _nextId++,
       label = TextEditingController(text: label),
       href = TextEditingController(text: href);

  factory _EditableCarouselItem.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _EditableCarouselItem(
      label: cmsStringValue(json['label']),
      href: cmsStringValue(json['href']),
      media: CmsMediaRef.maybeFromJson(json['media']),
    );
  }

  _EditableCarouselItem clone() {
    return _EditableCarouselItem(
      label: label.text,
      href: href.text,
      media: media,
    );
  }

  void addListener(VoidCallback listener) {
    label.addListener(listener);
    href.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    label.removeListener(listener);
    href.removeListener(listener);
  }

  void dispose() {
    label.dispose();
    href.dispose();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label.text.trim(),
      'href': href.text.trim(),
      'media': cmsMediaMap(media),
    };
  }
}

class _EmptyItemsState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyItemsState({required this.onAdd});

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
          const Icon(Icons.view_carousel_outlined, color: Color(0xFF6F6F6F)),
          const SizedBox(height: 8),
          const Text(
            'Aucune tuile',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ajoutez des tuiles qui apparaîtront dans le carrousel horizontal.',
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

class _CarouselItemEditorCard extends StatelessWidget {
  final int index;
  final _EditableCarouselItem item;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final ValueChanged<CmsMediaRef?> onMediaChanged;

  const _CarouselItemEditorCard({
    super.key,
    required this.index,
    required this.item,
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
    final title = item.label.text.trim().isEmpty
        ? 'Tuile ${index + 1}'
        : 'Tuile — ${item.label.text.trim()}';
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
                _CarouselItemActionButton(
                  icon: Icons.arrow_upward,
                  tooltip: 'Monter',
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
                _CarouselItemActionButton(
                  icon: Icons.arrow_downward,
                  tooltip: 'Descendre',
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
                _CarouselItemActionButton(
                  icon: Icons.content_copy_outlined,
                  tooltip: 'Dupliquer',
                  onPressed: onDuplicate,
                ),
                _CarouselItemActionButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Supprimer',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.label,
              decoration: const InputDecoration(
                labelText: 'Libellé *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.href,
              decoration: const InputDecoration(
                labelText: 'Lien *',
                hintText: '/catalog',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            CmsMediaSlotField(
              label: 'Média',
              value: item.media,
              onChanged: onMediaChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselItemActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CarouselItemActionButton({
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
