import 'package:flutter/material.dart';

import 'cms_form_fields.dart';

/// Editor for the `category_split_tabs` section: edit the segment fallback
/// items, the default active segment, and the optional expanded-header title.
/// The tabs ↔ expansible design is stored in global navigation settings.
class CategorySplitTabsForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const CategorySplitTabsForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CategorySplitTabsForm> createState() => _CategorySplitTabsFormState();
}

class _CategorySplitTabsFormState extends State<CategorySplitTabsForm> {
  late TextEditingController _expansibleTitle;
  late int _defaultActiveIndex;
  late List<_EditableTab> _items;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant CategorySplitTabsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    _expansibleTitle = TextEditingController(
      text: cmsStringValue(config['expansibleTitle']),
    );
    _expansibleTitle.addListener(_emit);
    _items = cmsListValue(config['items'])
        .whereType<Map>()
        .map((item) {
          final editable = _EditableTab.fromJson(item);
          editable.addListener(_emit);
          return editable;
        })
        .toList(growable: true);
    final rawIndex = config['defaultActiveIndex'];
    final index = rawIndex is num ? rawIndex.toInt() : 0;
    _defaultActiveIndex = _clampActiveIndex(index);
  }

  int _clampActiveIndex(int index) {
    if (_items.isEmpty) return 0;
    if (index < 0 || index >= _items.length) return 0;
    return index;
  }

  void _disposeControllers() {
    _expansibleTitle.removeListener(_emit);
    _expansibleTitle.dispose();
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
      'schemaVersion': 1,
      'expansibleTitle': cmsTrimToNull(_expansibleTitle.text),
      'defaultActiveIndex': _clampActiveIndex(_defaultActiveIndex),
      'items': _items.map((item) => item.toJson()).toList(growable: false),
    };
  }

  void _emit() => widget.onChanged(_buildConfig());

  void _addItem() {
    final item = _EditableTab(label: 'Nouveau segment', href: '/sport/homme');
    item.addListener(_emit);
    setState(() => _items.add(item));
    _emit();
  }

  void _removeItem(int index) {
    final item = _items.removeAt(index);
    item.removeListener(_emit);
    item.dispose();
    _defaultActiveIndex = _clampActiveIndex(_defaultActiveIndex);
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
              const CmsFormSectionHeader(label: 'En-tête (mode Expansible)'),
              const SizedBox(height: 12),
              TextField(
                controller: _expansibleTitle,
                decoration: const InputDecoration(
                  labelText: 'Titre de l\'en-tête (déplié)',
                  hintText: 'Parcourir',
                  helperText:
                      'Le choix Onglets / Expansible se règle dans Navigation. '
                      'Replié, l\'en-tête affiche le segment actif.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: CmsFormSectionHeader(label: 'Segments (onglets)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_items.isEmpty)
                const Text(
                  'Aucun segment.',
                  style: TextStyle(color: Color(0xFF6F6F6F)),
                )
              else
                for (var index = 0; index < _items.length; index++) ...[
                  _TabEditorCard(
                    key: ValueKey(_items[index].id),
                    index: index,
                    item: _items[index],
                    canMoveUp: index > 0,
                    canMoveDown: index < _items.length - 1,
                    onMoveUp: () => _moveItem(index, index - 1),
                    onMoveDown: () => _moveItem(index, index + 1),
                    onRemove: () => _removeItem(index),
                  ),
                  if (index < _items.length - 1) const SizedBox(height: 12),
                ],
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _clampActiveIndex(_defaultActiveIndex),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Segment actif par défaut',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (var i = 0; i < _items.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(
                          _items[i].label.text.trim().isEmpty
                              ? 'Segment ${i + 1}'
                              : _items[i].label.text.trim(),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _defaultActiveIndex = value);
                    _emit();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableTab {
  static int _nextId = 0;

  final int id;
  final TextEditingController label;
  final TextEditingController href;
  final TextEditingController segment;

  _EditableTab({required String label, required String href, String? segment})
    : id = _nextId++,
      label = TextEditingController(text: label),
      href = TextEditingController(text: href),
      segment = TextEditingController(text: segment ?? '');

  factory _EditableTab.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return _EditableTab(
      label: cmsStringValue(json['label']),
      href: cmsStringValue(json['href']),
      segment: cmsStringValue(json['segment']),
    );
  }

  void addListener(VoidCallback listener) {
    label.addListener(listener);
    href.addListener(listener);
    segment.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    label.removeListener(listener);
    href.removeListener(listener);
    segment.removeListener(listener);
  }

  void dispose() {
    label.dispose();
    href.dispose();
    segment.dispose();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label.text.trim(),
      'href': href.text.trim(),
      'segment': cmsTrimToNull(segment.text),
    };
  }
}

class _TabEditorCard extends StatelessWidget {
  final int index;
  final _EditableTab item;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  const _TabEditorCard({
    super.key,
    required this.index,
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
                    item.label.text.trim().isEmpty
                        ? 'Segment ${index + 1}'
                        : item.label.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Monter',
                  onPressed: canMoveUp ? onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward, size: 17),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                ),
                IconButton(
                  tooltip: 'Descendre',
                  onPressed: canMoveDown ? onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward, size: 17),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 17),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
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
                hintText: '/sport/homme',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.segment,
              decoration: const InputDecoration(
                labelText: 'Segment',
                hintText: 'homme / femme / enfant',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
