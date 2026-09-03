import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../application/navigation/navigation_editor_options.dart';
import '../../application/navigation/save_navigation_item.dart';
import 'drawer_editorial_tiles_editor_dialog.dart';
import '../providers/navigation_editor_options_provider.dart';
import '../providers/navigation_item_editor_controller.dart';

class NavigationItemEditorDialog extends ConsumerStatefulWidget {
  final String menuId;
  final String authToken;
  final int depth;
  final int position;
  final String? parentId;
  final String title;
  final DrawerNavigationItemData? initialItem;
  final bool hasChildren;

  const NavigationItemEditorDialog({
    super.key,
    required this.menuId,
    required this.authToken,
    required this.depth,
    required this.position,
    required this.title,
    this.parentId,
    this.initialItem,
    this.hasChildren = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String menuId,
    required String authToken,
    required int depth,
    required int position,
    required String title,
    String? parentId,
    DrawerNavigationItemData? initialItem,
    bool hasChildren = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => NavigationItemEditorDialog(
        menuId: menuId,
        authToken: authToken,
        depth: depth,
        position: position,
        title: title,
        parentId: parentId,
        initialItem: initialItem,
        hasChildren: hasChildren,
      ),
    );
  }

  @override
  ConsumerState<NavigationItemEditorDialog> createState() =>
      _NavigationItemEditorDialogState();
}

class _NavigationItemEditorDialogState
    extends ConsumerState<NavigationItemEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _pageKeyController;
  late final TextEditingController _urlController;
  DrawerNavigationItemType _itemType = DrawerNavigationItemType.page;
  DrawerNavigationPlacement _placement = DrawerNavigationPlacement.nav;
  DrawerNavigationDesktopTemplate _desktopTemplate =
      DrawerNavigationDesktopTemplate.listOnly;
  String? _categoryId;
  String? _productId;
  String? _promoMediaId;
  late final NavigationEditorOptionsRequest _optionsRequest;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.initialItem;
    _labelController = TextEditingController(text: initialItem?.label ?? '');
    _pageKeyController = TextEditingController(
      text: initialItem?.pageKey ?? '',
    );
    _urlController = TextEditingController(text: initialItem?.url ?? '');
    _itemType = initialItem?.itemType ?? DrawerNavigationItemType.page;
    _placement = initialItem?.placement ?? DrawerNavigationPlacement.nav;
    _desktopTemplate =
        initialItem?.desktopDrawerTemplate ??
        DrawerNavigationDesktopTemplate.listOnly;
    _categoryId = initialItem?.categoryId;
    _productId = initialItem?.productId;
    _promoMediaId = initialItem?.promoMediaId;
    _optionsRequest = NavigationEditorOptionsRequest(
      authToken: widget.authToken,
      baseUrl: ref.read(apiBaseUrlProvider),
      initialItem: widget.initialItem,
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _pageKeyController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRootItem = widget.depth == 0;
    final optionsAsync = ref.watch(
      navigationEditorOptionsProvider(_optionsRequest),
    );
    final saveAsync = ref.watch(navigationItemEditorControllerProvider);
    final options = optionsAsync.value ?? NavigationEditorOptionsBundle.empty;
    final isSaving = saveAsync.isLoading;

    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (optionsAsync.isLoading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').isEmpty) {
                      return 'Champ requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<DrawerNavigationItemType>(
                  initialValue: _itemType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Type de cible',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DrawerNavigationItemType.category,
                      child: _DropdownLabel('Category'),
                    ),
                    DropdownMenuItem(
                      value: DrawerNavigationItemType.product,
                      child: _DropdownLabel('Product'),
                    ),
                    DropdownMenuItem(
                      value: DrawerNavigationItemType.page,
                      child: _DropdownLabel('Page'),
                    ),
                    DropdownMenuItem(
                      value: DrawerNavigationItemType.external,
                      child: _DropdownLabel('External'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _itemType = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (_itemType == DrawerNavigationItemType.category)
                  _buildOptionDropdown(
                    label: 'Catégorie cible',
                    value: _categoryId,
                    options: options.categories,
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                if (_itemType == DrawerNavigationItemType.product)
                  _buildOptionDropdown(
                    label: 'Produit cible',
                    value: _productId,
                    options: options.products,
                    onChanged: (value) => setState(() => _productId = value),
                  ),
                if (_itemType == DrawerNavigationItemType.page)
                  TextFormField(
                    controller: _pageKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Page key',
                      hintText: 'ex. gifts, haute_couture',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Champ requis';
                      }
                      final pageKeyPattern = RegExp(r'^[a-z0-9_]+$');
                      if (!pageKeyPattern.hasMatch(trimmed)) {
                        return 'Format attendu: a-z, 0-9 et _';
                      }
                      return null;
                    },
                  ),
                if (_itemType == DrawerNavigationItemType.external)
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL externe',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Champ requis';
                      }
                      final uri = Uri.tryParse(trimmed);
                      if (uri == null || !uri.hasScheme) {
                        return 'URL invalide';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),
                DropdownButtonFormField<DrawerNavigationPlacement>(
                  initialValue: _placement,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Placement',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DrawerNavigationPlacement.nav,
                      child: _DropdownLabel('nav'),
                    ),
                    DropdownMenuItem(
                      value: DrawerNavigationPlacement.promo,
                      child: _DropdownLabel('promo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _placement = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _buildOptionDropdown(
                  label: 'Média promo',
                  value: _promoMediaId,
                  options: options.medias,
                  includeEmptyOption: true,
                  emptyLabel: 'Aucun',
                  onChanged: (value) => setState(() => _promoMediaId = value),
                ),
                if (isRootItem) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<DrawerNavigationDesktopTemplate>(
                    initialValue: _desktopTemplate,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Template desktop',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DrawerNavigationDesktopTemplate.listOnly,
                        child: _DropdownLabel('list_only'),
                      ),
                      DropdownMenuItem(
                        value: DrawerNavigationDesktopTemplate.heroSingle,
                        child: _DropdownLabel('hero_single'),
                      ),
                      DropdownMenuItem(
                        value: DrawerNavigationDesktopTemplate.promoGrid2x2,
                        child: _DropdownLabel('promo_grid_2x2'),
                      ),
                      DropdownMenuItem(
                        value: DrawerNavigationDesktopTemplate.promoStack2,
                        child: _DropdownLabel('promo_stack_2'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _desktopTemplate = value;
                      });
                    },
                  ),
                ],
                if (optionsAsync.hasError) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Chargement des options incomplet: ${optionsAsync.error}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ],
                if (widget.hasChildren) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Cet item a déjà des enfants: le template desktop reste porté par ce parent.',
                    style: TextStyle(color: Color(0xFF697586), fontSize: 13),
                  ),
                ],
                if (widget.initialItem != null) ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: isSaving ? null : _openEditorialTilesEditor,
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: const Text('Éditer les tiles'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: isSaving ? null : _save,
          child: isSaving
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
    );
  }

  Widget _buildOptionDropdown({
    required String label,
    required String? value,
    required List<NavigationEditorOption> options,
    required ValueChanged<String?> onChanged,
    bool includeEmptyOption = false,
    String emptyLabel = 'Aucun',
  }) {
    final normalizedOptions = dedupeEditorOptions(options);
    final selectedValue =
        value != null && normalizedOptions.any((option) => option.id == value)
        ? value
        : null;

    return DropdownButtonFormField<String?>(
      initialValue: selectedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (includeEmptyOption)
          DropdownMenuItem<String?>(
            value: null,
            child: _DropdownLabel(emptyLabel),
          ),
        for (final option in normalizedOptions)
          DropdownMenuItem<String?>(
            value: option.id,
            child: _DropdownLabel(option.label),
          ),
      ],
      selectedItemBuilder: (context) => [
        if (includeEmptyOption) _DropdownLabel(emptyLabel),
        for (final option in normalizedOptions) _DropdownLabel(option.label),
      ],
      onChanged: onChanged,
      validator: (selected) {
        if (!includeEmptyOption && (selected == null || selected.isEmpty)) {
          return 'Champ requis';
        }
        return null;
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final initialItem = widget.initialItem;
    final saved = await ref
        .read(navigationItemEditorControllerProvider.notifier)
        .save(
          NavigationItemEditorSaveRequest(
            authToken: widget.authToken,
            baseUrl: ref.read(apiBaseUrlProvider),
            input: SaveNavigationItemInput(
              menuId: widget.menuId,
              parentId: widget.parentId,
              position: widget.position,
              depth: widget.depth,
              label: _labelController.text,
              itemType: _itemType,
              categoryId: _categoryId,
              productId: _productId,
              pageKey: _pageKeyController.text,
              url: _urlController.text,
              promoMediaId: _promoMediaId,
              placement: _placement,
              desktopTemplate: _desktopTemplate,
              isActive: initialItem?.isActive ?? true,
              isHidden: initialItem?.isHidden ?? false,
              config: initialItem?.config ?? const {},
              recordId: initialItem?.id,
            ),
          ),
        );

    if (!mounted) {
      return;
    }

    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = ref.read(navigationItemEditorControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur lors de l’enregistrement: $error'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _openEditorialTilesEditor() async {
    final item = widget.initialItem;
    if (item == null) {
      return;
    }
    final changed = await DrawerEditorialTilesEditorDialog.show(
      context,
      authToken: widget.authToken,
      item: item,
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _DropdownLabel extends StatelessWidget {
  final String text;

  const _DropdownLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
