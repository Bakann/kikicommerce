import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../../application/catalog/catalog_invalidations.dart';
import '../../../../application/cms/cms_models.dart';
import '../../../../application/navigation/drawer_navigation_models.dart';
import '../../../providers/catalog_invalidator_provider.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/navigation_providers.dart';
import '../../drawer/category_drawer_widgets.dart';
import '../../drawer/drawer_category_list_editor.dart';
import '../../drawer/drawer_root_list_editor.dart';
import '../cms_admin_auth.dart';
import '../cms_hex_color.dart';
import '../sections/category_banner_strip_resolver.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

/// Structured editor for `category_banner_strip` section configs.
///
/// The section always mirrors the live drawer (`main_drawer`), so the form
/// is mostly a wrapper around the drawer admin affordances:
///
/// - **Type du drawer live** (Navigation / Catégories): toggles the menu's
///   `displayMode` field globally. Effects the live drawer everywhere it is
///   rendered, not just this section.
/// - **Root list editor**: full drag-reorder / edit / delete / toggle-hidden
///   / add-child affordances, identical to the live drawer's root column.
/// - **Fond commun du strip**: section-local background image rendered behind
///   the first three visible banners only.
/// - **Apparence des bannières**: section-local image + gradient overrides
///   per resolved banner, persisted in the section config under
///   `bannerAppearance` (keyed by navigation item id / category id) when the
///   admin clicks "Enregistrer".
///
/// Drawer mutations go straight to PocketBase; only the appearance overrides
/// flow through [onChanged] and the dialog's save.
class CategoryBannerStripForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const CategoryBannerStripForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  ConsumerState<CategoryBannerStripForm> createState() =>
      _CategoryBannerStripFormState();
}

class _CategoryBannerStripFormState
    extends ConsumerState<CategoryBannerStripForm> {
  bool _isUpdatingDisplayMode = false;
  late Map<String, dynamic> _config;

  @override
  void initState() {
    super.initState();
    _config = {
      ...widget.initialConfig,
      'schemaVersion': widget.initialConfig['schemaVersion'] ?? 1,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(_config);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawAppearance = _config['bannerAppearance'];
    final appearanceJsonById = rawAppearance is Map
        ? Map<String, dynamic>.from(rawAppearance)
        : const <String, dynamic>{};
    final sharedBackgroundMedia = CmsMediaRef.maybeFromJson(
      _config['sharedBackgroundMedia'],
    );
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerScopeSelector(
                isSaving: _isUpdatingDisplayMode,
                onChanged: _updateDisplayMode,
              ),
              const SizedBox(height: 20),
              const _ScopedListEditor(),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Fond commun du strip'),
              const SizedBox(height: 4),
              const Text(
                'Une image administrée une seule fois, rendue derrière les '
                '3 premières bannières visibles. Si une 4e bannière est '
                'affichée, elle garde son fond individuel.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 10),
              CmsMediaSlotField(
                label: 'Image commune (3 premières visibles)',
                value: sharedBackgroundMedia,
                onChanged: _updateSharedBackgroundMedia,
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Apparence des bannières'),
              const SizedBox(height: 4),
              const Text(
                'Image et fond dégradé propres à cette section, par bannière. '
                'Appliqués après "Enregistrer".',
                style: TextStyle(fontSize: 12, color: Color(0xFF6F6F6F)),
              ),
              const SizedBox(height: 10),
              _BannerAppearanceEditor(
                sourceMode: CategoryBannerStripSourceMode.fromWireName(
                  _config['sourceMode'] as String?,
                ),
                sourceCategoryId: (_config['sourceCategoryId'] as String?)
                    ?.trim(),
                appearanceJsonById: appearanceJsonById,
                onEntryChanged: _updateAppearance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateSharedBackgroundMedia(CmsMediaRef? media) {
    final mediaMap = cmsMediaMap(media);
    setState(() {
      _config = {..._config};
      if (mediaMap == null) {
        _config.remove('sharedBackgroundMedia');
      } else {
        _config['sharedBackgroundMedia'] = mediaMap;
      }
    });
    widget.onChanged(_config);
  }

  void _updateAppearance(String entryId, Map<String, dynamic>? appearance) {
    final rawAppearance = _config['bannerAppearance'];
    final next = rawAppearance is Map
        ? Map<String, dynamic>.from(rawAppearance)
        : <String, dynamic>{};
    if (appearance == null || appearance.isEmpty) {
      next.remove(entryId);
    } else {
      next[entryId] = appearance;
    }
    setState(() {
      _config = {..._config};
      if (next.isEmpty) {
        _config.remove('bannerAppearance');
      } else {
        _config['bannerAppearance'] = next;
      }
    });
    widget.onChanged(_config);
  }

  Future<void> _updateDisplayMode(DrawerEditScope nextScope) async {
    final nextSource = _liveSourceForScope(nextScope);
    final drawer = ref.read(mainDrawerNavigationProvider).value;
    final menu = drawer?.menu;
    if (menu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de changer le type : aucun menu `main_drawer` n\'est configuré.',
          ),
        ),
      );
      return;
    }
    if (menu.liveSource == nextSource) {
      return;
    }

    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    setState(() {
      _isUpdatingDisplayMode = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final displayMode = displayModeForDrawerLiveSource(nextSource);

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_menus',
        recordId: menu.id,
        data: {
          'name': menu.name.isNotEmpty ? menu.name : 'Main drawer',
          'code': menu.code.isNotEmpty ? menu.code : 'main_drawer',
          'displayMode': displayMode,
          'isActive': true,
        },
      );
      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, [
        ...invalidationsForAdminSave(
          collection: 'navigation_menus',
          recordId: menu.id,
          data: {'displayMode': displayMode, 'isActive': true},
        ),
      ]);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              nextSource == DrawerLiveSource.categories
                  ? 'Le drawer live utilisera les catégories.'
                  : 'Le drawer live utilisera la navigation.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement de type: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDisplayMode = false;
        });
      }
    }
  }

  DrawerLiveSource _liveSourceForScope(DrawerEditScope scope) {
    return switch (scope) {
      DrawerEditScope.navigation => DrawerLiveSource.navigation,
      DrawerEditScope.categories => DrawerLiveSource.categories,
    };
  }
}

/// Renders the right root-level editor depending on the menu's live source:
/// navigation items when `displayMode = drawer`, categories when
/// `displayMode = categories`. Both routes mutate the same backing data
/// the live drawer reads from.
class _ScopedListEditor extends ConsumerWidget {
  const _ScopedListEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mainDrawerNavigationProvider);
    final liveSource =
        async.value?.menu?.liveSource ?? DrawerLiveSource.navigation;
    return switch (liveSource) {
      DrawerLiveSource.categories => const DrawerCategoryListEditor(),
      DrawerLiveSource.navigation => const DrawerRootListEditor(
        addEntryLabel: 'Nouvelle entrée',
      ),
    };
  }
}

class _DrawerScopeSelector extends ConsumerWidget {
  final bool isSaving;
  final ValueChanged<DrawerEditScope> onChanged;

  const _DrawerScopeSelector({required this.isSaving, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mainDrawerNavigationProvider);
    final liveSource =
        async.value?.menu?.liveSource ?? DrawerLiveSource.navigation;
    final scope = liveSource == DrawerLiveSource.categories
        ? DrawerEditScope.categories
        : DrawerEditScope.navigation;
    return DrawerEditScopeSelector(
      selectedScope: scope,
      isSaving: isSaving,
      onChanged: onChanged,
    );
  }
}

/// Lists the banners the section will render (same resolution as the
/// storefront host, hidden entries included) and exposes the per-banner
/// appearance overrides: image + gradient colors.
class _BannerAppearanceEditor extends ConsumerWidget {
  final CategoryBannerStripSourceMode sourceMode;
  final String? sourceCategoryId;
  final Map<String, dynamic> appearanceJsonById;
  final void Function(String entryId, Map<String, dynamic>? appearance)
  onEntryChanged;

  const _BannerAppearanceEditor({
    required this.sourceMode,
    required this.sourceCategoryId,
    required this.appearanceJsonById,
    required this.onEntryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sourceMode == CategoryBannerStripSourceMode.configuredBanners) {
      return const _AppearanceInfoMessage(
        text:
            'Cette section utilise des bannières configurées (`banners`) : '
            'image et dégradé se règlent directement sur chaque bannière '
            'dans l\'onglet JSON.',
      );
    }

    final drawerAsync = ref.watch(mainDrawerNavigationProvider);
    final drawer = drawerAsync.value;
    if (drawer == null && drawerAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final liveSource = drawer?.menu?.liveSource ?? DrawerLiveSource.navigation;
    final wantsCategoryChildren =
        sourceMode == CategoryBannerStripSourceMode.categoryChildren &&
        (sourceCategoryId?.isNotEmpty ?? false);
    final categories =
        wantsCategoryChildren || liveSource == DrawerLiveSource.categories
        ? ref.watch(drawerCategoriesProvider).value
        : null;

    final entries = wantsCategoryChildren
        ? resolveCategoryChildrenBannerEntries(
            categories: categories,
            parentId: sourceCategoryId ?? '',
            includeHidden: true,
          )
        : resolveCategoryBannerEntries(
            drawerResult: drawer,
            categories: categories,
            includeHidden: true,
          );
    if (entries.isEmpty) {
      return const _AppearanceInfoMessage(
        text:
            'Aucune bannière à styler pour l\'instant — ajoute des entrées '
            'dans la liste ci-dessus.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          _BannerAppearanceRow(
            key: ValueKey('appearance-${entry.id}'),
            entry: entry,
            appearanceJson: appearanceJsonById[entry.id] is Map
                ? Map<String, dynamic>.from(appearanceJsonById[entry.id] as Map)
                : null,
            onChanged: (json) => onEntryChanged(entry.id, json),
          ),
      ],
    );
  }
}

class _BannerAppearanceRow extends StatefulWidget {
  final CategoryBannerEntry entry;
  final Map<String, dynamic>? appearanceJson;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const _BannerAppearanceRow({
    super.key,
    required this.entry,
    required this.appearanceJson,
    required this.onChanged,
  });

  @override
  State<_BannerAppearanceRow> createState() => _BannerAppearanceRowState();
}

class _BannerAppearanceRowState extends State<_BannerAppearanceRow> {
  // Controllers are seeded once from the stored config; afterwards every edit
  // flows outward through [widget.onChanged], so no inbound sync is needed
  // (rows are keyed by entry id and the form never rewrites the config
  // underneath them).
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _suppressEmit = false;

  CmsMediaRef? get _media =>
      CmsMediaRef.maybeFromJson(widget.appearanceJson?['media']);

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: (widget.appearanceJson?['gradientStart'] as String?) ?? '',
    );
    _endController = TextEditingController(
      text: (widget.appearanceJson?['gradientEnd'] as String?) ?? '',
    );
    _startController.addListener(_emitFromFields);
    _endController.addListener(_emitFromFields);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _emitFromFields() {
    if (_suppressEmit) return;
    widget.onChanged(
      _buildJson(
        media: _media,
        start: _normalizedHex(_startController.text),
        end: _normalizedHex(_endController.text),
      ),
    );
  }

  void _onMediaChanged(CmsMediaRef? media) {
    widget.onChanged(
      _buildJson(
        media: media,
        start: _normalizedHex(_startController.text),
        end: _normalizedHex(_endController.text),
      ),
    );
  }

  void _reset() {
    _suppressEmit = true;
    _startController.clear();
    _endController.clear();
    _suppressEmit = false;
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final startColor = cmsColorFromHex(_startController.text);
    final endColor = cmsColorFromHex(_endController.text);
    final hasOverride =
        _media != null ||
        _startController.text.trim().isNotEmpty ||
        _endController.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDADAD2)),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: _GradientSwatch(
          start: startColor,
          end: endColor,
          hasMedia: _media != null,
        ),
        title: Text(
          widget.entry.label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          widget.entry.isHidden
              ? 'Masquée dans le drawer'
              : (hasOverride
                    ? 'Apparence personnalisée'
                    : 'Apparence par défaut'),
          style: const TextStyle(fontSize: 11, color: Color(0xFF6F6F6F)),
        ),
        children: [
          CmsMediaSlotField(
            label: 'Image (fondue depuis la droite)',
            value: _media,
            onChanged: _onMediaChanged,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HexColorField(
                  label: 'Dégradé — début',
                  controller: _startController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HexColorField(
                  label: 'Dégradé — fin',
                  controller: _endController,
                ),
              ),
            ],
          ),
          if (hasOverride)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Réinitialiser'),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic>? _buildJson({
  CmsMediaRef? media,
  String? start,
  String? end,
}) {
  final json = <String, dynamic>{};
  final mediaMap = cmsMediaMap(media);
  if (mediaMap != null) json['media'] = mediaMap;
  if (start != null) json['gradientStart'] = start;
  if (end != null) json['gradientEnd'] = end;
  return json.isEmpty ? null : json;
}

String? _normalizedHex(String raw) {
  if (raw.trim().isEmpty) return null;
  final color = cmsColorFromHex(raw);
  return color == null ? null : cmsHexFromColor(color);
}

/// Mini preview of the banner background: gradient (or flat color) with the
/// default dark tone as fallback, plus an icon when an image is set.
class _GradientSwatch extends StatelessWidget {
  final Color? start;
  final Color? end;
  final bool hasMedia;

  const _GradientSwatch({
    required this.start,
    required this.end,
    required this.hasMedia,
  });

  @override
  Widget build(BuildContext context) {
    final flat = start ?? end ?? const Color(0xFF2A3038);
    final gradient = start != null && end != null
        ? LinearGradient(colors: [start!, end!])
        : null;
    final luminance = flat.computeLuminance();
    return Container(
      width: 52,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: flat,
        gradient: gradient,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDADAD2)),
      ),
      child: hasMedia
          ? Icon(
              Icons.image_outlined,
              size: 14,
              color: luminance > 0.5 ? const Color(0xFF111111) : Colors.white,
            )
          : null,
    );
  }
}

class _HexColorField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _HexColorField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final color = cmsColorFromHex(text);
    return TextField(
      controller: controller,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: '#2A3038',
        errorText: text.trim().isNotEmpty && color == null
            ? 'Hex attendu : #RRGGBB'
            : null,
        border: const OutlineInputBorder(),
        isDense: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color ?? Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFFDADAD2)),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 38,
          minHeight: 38,
        ),
      ),
    );
  }
}

class _AppearanceInfoMessage extends StatelessWidget {
  final String text;

  const _AppearanceInfoMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F2),
        border: Border.all(color: const Color(0xFFDADAD2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF6F6F6F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
            ),
          ),
        ],
      ),
    );
  }
}
