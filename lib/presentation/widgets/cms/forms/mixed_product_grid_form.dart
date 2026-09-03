import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

const List<String> kGridSortOptions = [
  'manual',
  'newest',
  'price_asc',
  'price_desc',
];

const List<String> kGridInsertTypes = [
  'category_tile',
  'editorial_campaign_tile',
  'universe_tile',
];

const List<String> kGridDisplaySizes = ['small', 'wide', 'full_mobile'];

class MixedProductGridForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const MixedProductGridForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<MixedProductGridForm> createState() => _MixedProductGridFormState();
}

class _MixedProductGridFormState extends State<MixedProductGridForm> {
  late TextEditingController _limit;
  late TextEditingController _aspectRatio;
  late TextEditingController _excludedProductIds;
  late int _columnsMobile;
  late int _columnsTablet;
  late int _columnsDesktop;
  late bool _toolbarEnabled;
  late bool _stickyToolbar;
  late bool _showSort;
  late bool _showFilter;
  late String _defaultSort;
  late bool _showWishlist;
  late bool _showSummary;
  late bool _showBadges;
  late bool _showQuickAdd;
  late bool _showPrices;
  late List<_EditablePin> _pins;
  late List<_EditableInsert> _inserts;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant MixedProductGridForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    final parsed = MixedProductGridConfig.fromJson(config);
    _limit = TextEditingController(text: '${parsed.source.limit}');
    _aspectRatio = TextEditingController(text: parsed.aspectRatio);
    _excludedProductIds = TextEditingController(
      text: parsed.excludedProductIds.join('\n'),
    );
    _columnsMobile = parsed.columnsMobile;
    _columnsTablet = parsed.columnsTablet;
    _columnsDesktop = parsed.columnsDesktop;
    _toolbarEnabled = parsed.toolbar.enabled;
    _stickyToolbar = parsed.toolbar.stickyToolbar;
    _showSort = parsed.toolbar.showSort;
    _showFilter = parsed.toolbar.showFilter;
    _defaultSort = parsed.toolbar.defaultSort;
    _showWishlist = parsed.productCard.showWishlist;
    _showSummary = parsed.productCard.showSummary;
    _showBadges = parsed.productCard.showBadges;
    _showQuickAdd = parsed.productCard.showQuickAdd;
    _showPrices = parsed.productCard.showPrices;
    _pins = parsed.pinnedProducts
        .map(_EditablePin.fromConfig)
        .toList(growable: true);
    _inserts = parsed.inserts
        .where((insert) => insert is! UnknownGridInsert)
        .map(_EditableInsert.fromConfig)
        .toList(growable: true);
    for (final controller in [_limit, _aspectRatio, _excludedProductIds]) {
      controller.addListener(_emit);
    }
    for (final pin in _pins) {
      pin.addListener(_emit);
    }
    for (final insert in _inserts) {
      insert.addListener(_emit);
    }
  }

  void _disposeControllers() {
    for (final controller in [_limit, _aspectRatio, _excludedProductIds]) {
      controller.removeListener(_emit);
      controller.dispose();
    }
    for (final pin in _pins) {
      pin.removeListener(_emit);
      pin.dispose();
    }
    for (final insert in _inserts) {
      insert.removeListener(_emit);
      insert.dispose();
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
      'source': {
        'type': 'routeCategory',
        'limit': int.tryParse(_limit.text.trim()) ?? 48,
        'sort': 'manual',
      },
      'columnsMobile': _columnsMobile,
      'columnsTablet': _columnsTablet,
      'columnsDesktop': _columnsDesktop,
      'aspectRatio': cmsTrimToNull(_aspectRatio.text) ?? '0.64',
      'toolbar': {
        'enabled': _toolbarEnabled,
        'stickyToolbar': _stickyToolbar,
        'showSort': _showSort,
        'showFilter': _showFilter,
        'defaultSort': _defaultSort,
        'sortOptions': kGridSortOptions,
      },
      'productCard': {
        'showWishlist': _showWishlist,
        'showSummary': _showSummary,
        'showBadges': _showBadges,
        'showQuickAdd': _showQuickAdd,
        'showPrices': _showPrices,
      },
      'pinnedProducts': _pins.map((pin) => pin.toJson()).toList(),
      'excludedProductIds': _lineList(_excludedProductIds.text),
      'inserts': _inserts.map((insert) => insert.toJson()).toList(),
    };
  }

  void _emit() {
    widget.onChanged(_buildConfig());
  }

  void _addPin() {
    final pin = _EditablePin(productId: '', slotPosition: 0);
    pin.addListener(_emit);
    setState(() => _pins.add(pin));
    _emit();
  }

  void _removePin(int index) {
    final pin = _pins.removeAt(index);
    pin.removeListener(_emit);
    pin.dispose();
    setState(() {});
    _emit();
  }

  void _addInsert() {
    final insert = _EditableInsert(
      type: 'category_tile',
      slotPosition: 2,
      displaySize: 'small',
      title: 'Nouvelle insertion',
      href: '/catalog',
    );
    insert.addListener(_emit);
    setState(() => _inserts.add(insert));
    _emit();
  }

  void _duplicateInsert(int index) {
    final insert = _inserts[index].clone();
    insert.addListener(_emit);
    setState(() => _inserts.insert(index + 1, insert));
    _emit();
  }

  void _removeInsert(int index) {
    final insert = _inserts.removeAt(index);
    insert.removeListener(_emit);
    insert.dispose();
    setState(() {});
    _emit();
  }

  void _moveInsert(int from, int to) {
    if (to < 0 || to >= _inserts.length) return;
    final insert = _inserts.removeAt(from);
    _inserts.insert(to, insert);
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
              const CmsFormSectionHeader(label: 'Source produits'),
              const SizedBox(height: 12),
              TextFormField(
                enabled: false,
                initialValue: 'Catégorie de la page',
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre maximum de produits',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Affichage grille'),
              const SizedBox(height: 12),
              _ResponsiveFieldRow(
                children: [
                  _ColumnDropdown(
                    label: 'Colonnes mobile',
                    value: _columnsMobile,
                    onChanged: (value) {
                      setState(() => _columnsMobile = value);
                      _emit();
                    },
                  ),
                  _ColumnDropdown(
                    label: 'Colonnes tablette',
                    value: _columnsTablet,
                    onChanged: (value) {
                      setState(() => _columnsTablet = value);
                      _emit();
                    },
                  ),
                  _ColumnDropdown(
                    label: 'Colonnes desktop',
                    value: _columnsDesktop,
                    onChanged: (value) {
                      setState(() => _columnsDesktop = value);
                      _emit();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aspectRatio,
                decoration: const InputDecoration(
                  labelText: 'Ratio carte produit',
                  helperText: 'Ratio largeur / hauteur, ex: 0.64',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _BoolChip(
                    label: 'Wishlist',
                    value: _showWishlist,
                    onChanged: (value) {
                      setState(() => _showWishlist = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Résumé',
                    value: _showSummary,
                    onChanged: (value) {
                      setState(() => _showSummary = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Badges',
                    value: _showBadges,
                    onChanged: (value) {
                      setState(() => _showBadges = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Quick add',
                    value: _showQuickAdd,
                    onChanged: (value) {
                      setState(() => _showQuickAdd = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Prix',
                    value: _showPrices,
                    onChanged: (value) {
                      setState(() => _showPrices = value);
                      _emit();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Toolbar'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _BoolChip(
                    label: 'Afficher',
                    value: _toolbarEnabled,
                    onChanged: (value) {
                      setState(() => _toolbarEnabled = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Sticky',
                    value: _stickyToolbar,
                    onChanged: (value) {
                      setState(() => _stickyToolbar = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Tri',
                    value: _showSort,
                    onChanged: (value) {
                      setState(() => _showSort = value);
                      _emit();
                    },
                  ),
                  _BoolChip(
                    label: 'Filtre',
                    value: _showFilter,
                    onChanged: (value) {
                      setState(() => _showFilter = value);
                      _emit();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _defaultSort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tri par défaut',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                  DropdownMenuItem(
                    value: 'newest',
                    child: Text('Nouveautés', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text(
                      'Prix croissant',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text(
                      'Prix décroissant',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _defaultSort = value);
                  _emit();
                },
              ),
              const SizedBox(height: 24),
              _ListHeader(
                label: 'Produits mis en avant',
                actionLabel: 'Ajouter un produit',
                onPressed: _addPin,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _pins.length; i++) ...[
                _PinCard(pin: _pins[i], onRemove: () => _removePin(i)),
                const SizedBox(height: 12),
              ],
              const CmsFormSectionHeader(label: 'Produits exclus'),
              const SizedBox(height: 12),
              TextField(
                controller: _excludedProductIds,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'IDs produits exclus',
                  helperText: 'Un ID par ligne.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _ListHeader(
                label: 'Insertions éditoriales',
                actionLabel: 'Ajouter une insertion',
                onPressed: _addInsert,
              ),
              const SizedBox(height: 12),
              if (_inserts.isEmpty)
                _EmptyInsertState(onAdd: _addInsert)
              else
                for (var i = 0; i < _inserts.length; i++) ...[
                  _InsertCard(
                    index: i,
                    insert: _inserts[i],
                    canMoveUp: i > 0,
                    canMoveDown: i < _inserts.length - 1,
                    onMoveUp: () => _moveInsert(i, i - 1),
                    onMoveDown: () => _moveInsert(i, i + 1),
                    onDuplicate: () => _duplicateInsert(i),
                    onRemove: () => _removeInsert(i),
                    onChanged: () {
                      setState(() {});
                      _emit();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditablePin {
  final TextEditingController productId;
  final TextEditingController slotPosition;

  _EditablePin({required String productId, required int slotPosition})
    : productId = TextEditingController(text: productId),
      slotPosition = TextEditingController(text: '$slotPosition');

  factory _EditablePin.fromConfig(PinnedProductConfig config) {
    return _EditablePin(
      productId: config.productId,
      slotPosition: config.slotPosition,
    );
  }

  void addListener(VoidCallback listener) {
    productId.addListener(listener);
    slotPosition.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    productId.removeListener(listener);
    slotPosition.removeListener(listener);
  }

  void dispose() {
    productId.dispose();
    slotPosition.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId.text.trim(),
      'slotPosition': int.tryParse(slotPosition.text.trim()) ?? 0,
    };
  }
}

class _EditableInsert {
  static int _nextId = 0;

  final int id;
  String type;
  String displaySize;
  CmsMediaRef? imageMobile;
  CmsMediaRef? imageDesktop;
  final TextEditingController slotPosition;
  final TextEditingController title;
  final TextEditingController body;
  final TextEditingController href;
  final TextEditingController ctaLabel;
  final TextEditingController ctaHref;
  final TextEditingController aspectRatio;

  _EditableInsert({
    required this.type,
    required int slotPosition,
    required this.displaySize,
    required String title,
    String? body,
    required String href,
    String? ctaLabel,
    String? ctaHref,
    String aspectRatio = '1/1',
    this.imageMobile,
    this.imageDesktop,
  }) : id = _nextId++,
       slotPosition = TextEditingController(text: '$slotPosition'),
       title = TextEditingController(text: title),
       body = TextEditingController(text: body ?? ''),
       href = TextEditingController(text: href),
       ctaLabel = TextEditingController(text: ctaLabel ?? ''),
       ctaHref = TextEditingController(text: ctaHref ?? ''),
       aspectRatio = TextEditingController(text: aspectRatio);

  factory _EditableInsert.fromConfig(GridInsertConfig insert) {
    return switch (insert) {
      CategoryTileInsert() => _EditableInsert(
        type: 'category_tile',
        slotPosition: insert.slotPosition,
        displaySize: insert.displaySize,
        title: insert.title,
        href: insert.href,
        aspectRatio: insert.aspectRatio,
        imageMobile: insert.imageMobile,
        imageDesktop: insert.imageDesktop,
      ),
      EditorialCampaignInsert() => _EditableInsert(
        type: 'editorial_campaign_tile',
        slotPosition: insert.slotPosition,
        displaySize: insert.displaySize,
        title: insert.title,
        body: insert.body,
        href: insert.cta?.href ?? '',
        ctaLabel: insert.cta?.label,
        ctaHref: insert.cta?.href,
        aspectRatio: insert.aspectRatio,
        imageMobile: insert.imageMobile,
        imageDesktop: insert.imageDesktop,
      ),
      UniverseInsert() => _EditableInsert(
        type: 'universe_tile',
        slotPosition: insert.slotPosition,
        displaySize: insert.displaySize,
        title: insert.title,
        body: insert.body,
        href: insert.href,
        aspectRatio: insert.aspectRatio,
        imageMobile: insert.imageMobile,
        imageDesktop: insert.imageDesktop,
      ),
      UnknownGridInsert() => _EditableInsert(
        type: 'category_tile',
        slotPosition: insert.slotPosition,
        displaySize: insert.displaySize,
        title: '',
        href: '/catalog',
        aspectRatio: insert.aspectRatio,
      ),
    };
  }

  _EditableInsert clone() {
    return _EditableInsert(
      type: type,
      slotPosition: int.tryParse(slotPosition.text.trim()) ?? 0,
      displaySize: displaySize,
      title: title.text,
      body: body.text,
      href: href.text,
      ctaLabel: ctaLabel.text,
      ctaHref: ctaHref.text,
      aspectRatio: aspectRatio.text,
      imageMobile: imageMobile,
      imageDesktop: imageDesktop,
    );
  }

  void addListener(VoidCallback listener) {
    for (final controller in [
      slotPosition,
      title,
      body,
      href,
      ctaLabel,
      ctaHref,
      aspectRatio,
    ]) {
      controller.addListener(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    for (final controller in [
      slotPosition,
      title,
      body,
      href,
      ctaLabel,
      ctaHref,
      aspectRatio,
    ]) {
      controller.removeListener(listener);
    }
  }

  void dispose() {
    for (final controller in [
      slotPosition,
      title,
      body,
      href,
      ctaLabel,
      ctaHref,
      aspectRatio,
    ]) {
      controller.dispose();
    }
  }

  Map<String, dynamic> toJson() {
    final base = <String, dynamic>{
      'type': type,
      'slotPosition': int.tryParse(slotPosition.text.trim()) ?? 0,
      'displaySize': displaySize,
      'title': title.text.trim(),
      'imageMobile': cmsMediaMap(imageMobile),
      'imageDesktop': cmsMediaMap(imageDesktop),
      'aspectRatio': cmsTrimToNull(aspectRatio.text) ?? '1/1',
    };
    if (type == 'editorial_campaign_tile') {
      base['body'] = cmsTrimToNull(body.text);
      base['cta'] = cmsCtaMap(label: ctaLabel.text, href: ctaHref.text);
      return base;
    }
    if (type == 'universe_tile') {
      base['body'] = cmsTrimToNull(body.text);
    }
    base['href'] = href.text.trim();
    return base;
  }
}

class _PinCard extends StatelessWidget {
  final _EditablePin pin;
  final VoidCallback onRemove;

  const _PinCard({required this.pin, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: pin.productId,
              decoration: const InputDecoration(
                labelText: 'ID produit',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: pin.slotPosition,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Position',
                helperText: '0 = premier',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _InsertCard extends StatelessWidget {
  final int index;
  final _EditableInsert insert;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _InsertCard({
    required this.index,
    required this.insert,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Insertion ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Monter',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'Descendre',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
              IconButton(
                tooltip: 'Dupliquer',
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResponsiveFieldRow(
            children: [
              DropdownButtonFormField<String>(
                initialValue: insert.type,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'category_tile',
                    child: Text(
                      'Tuile catégorie',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'editorial_campaign_tile',
                    child: Text('Campagne', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'universe_tile',
                    child: Text('Univers', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  insert.type = value;
                  onChanged();
                },
              ),
              TextField(
                controller: insert.slotPosition,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Après N produits',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: insert.displaySize,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Taille',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'small', child: Text('Petite')),
                  DropdownMenuItem(value: 'wide', child: Text('Large')),
                  DropdownMenuItem(
                    value: 'full_mobile',
                    child: Text(
                      'Pleine largeur mobile',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  insert.displaySize = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insert.title,
            decoration: const InputDecoration(
              labelText: 'Titre',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (insert.type != 'category_tile') ...[
            const SizedBox(height: 12),
            TextField(
              controller: insert.body,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Texte',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (insert.type == 'editorial_campaign_tile')
            _ResponsiveFieldRow(
              children: [
                TextField(
                  controller: insert.ctaLabel,
                  decoration: const InputDecoration(
                    labelText: 'CTA',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                TextField(
                  controller: insert.ctaHref,
                  decoration: const InputDecoration(
                    labelText: 'Lien CTA',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: insert.href,
              decoration: const InputDecoration(
                labelText: 'Lien',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: insert.aspectRatio,
            decoration: const InputDecoration(
              labelText: 'Ratio image',
              helperText: 'Exemples: 1/1, 4/5, 16/9',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          _ResponsiveFieldRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CmsMediaSlotField(
                label: 'Image mobile',
                value: insert.imageMobile,
                onChanged: (media) {
                  insert.imageMobile = media;
                  onChanged();
                },
              ),
              CmsMediaSlotField(
                label: 'Image desktop',
                value: insert.imageDesktop,
                onChanged: (media) {
                  insert.imageDesktop = media;
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColumnDropdown extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _ColumnDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (var i = 1; i <= 6; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const _ResponsiveFieldRow({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically =
            constraints.maxWidth < 520 ||
            children.length > 2 && constraints.maxWidth < 680;
        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i < children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _BoolChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BoolChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onPressed;

  const _ListHeader({
    required this.label,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: CmsFormSectionHeader(label: label)),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add, size: 16),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EditorCard extends StatelessWidget {
  final Widget child;

  const _EditorCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        border: Border.all(color: const Color(0xFFDADAD2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class _EmptyInsertState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyInsertState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return _EditorCard(
      child: Column(
        children: [
          const Icon(Icons.view_module_outlined, color: Color(0xFF6F6F6F)),
          const SizedBox(height: 8),
          const Text(
            'Aucune insertion éditoriale',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Ajouter une insertion'),
          ),
        ],
      ),
    );
  }
}

List<String> _lineList(String text) {
  return text
      .split(RegExp(r'[\n,;]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}
