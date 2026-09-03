import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/cms/cms_models.dart'
    show CmsSectionType, isVideoFilename;
import '../../providers/cms_page_editor_controller.dart';
import '../media_picker_modal.dart';
import 'cms_admin_auth.dart';
import 'cms_section_defaults.dart';
import 'forms/category_banner_strip_form.dart';
import 'forms/collection_hero_form.dart';
import 'forms/category_split_tabs_form.dart';
import 'forms/category_tiles_form.dart';
import 'forms/editorial_story_form.dart';
import 'forms/featured_products_form.dart';
import 'forms/hero_campaign_form.dart';
import 'forms/horizontal_tile_carousel_form.dart';
import 'forms/mixed_product_grid_form.dart';
import 'forms/service_cards_form.dart';

class CmsSectionEditorRequest {
  final CmsSectionType type;
  final String pageId;
  final int position;

  // create-mode fields
  final String? proposedSectionId;

  // edit-mode fields
  final String? sectionRecordId;
  final String? existingSectionId;
  final Map<String, dynamic>? initialConfig;

  const CmsSectionEditorRequest.create({
    required this.type,
    required this.pageId,
    required this.position,
    required String this.proposedSectionId,
  }) : sectionRecordId = null,
       existingSectionId = null,
       initialConfig = null;

  const CmsSectionEditorRequest.edit({
    required this.type,
    required this.pageId,
    required this.position,
    required String this.sectionRecordId,
    required String this.existingSectionId,
    required Map<String, dynamic> this.initialConfig,
  }) : proposedSectionId = null;

  bool get isCreate => sectionRecordId == null;
}

/// Section types that have a structured form view today. Others fall back to
/// the JSON-only editor.
bool _hasFormView(CmsSectionType type) {
  switch (type) {
    case CmsSectionType.heroCampaign:
    case CmsSectionType.editorialStory:
    case CmsSectionType.categoryTiles:
    case CmsSectionType.featuredProducts:
    case CmsSectionType.serviceCards:
    case CmsSectionType.collectionHero:
    case CmsSectionType.mixedProductGrid:
    case CmsSectionType.horizontalTileCarousel:
    case CmsSectionType.categoryBannerStrip:
    case CmsSectionType.categorySplitTabs:
      return true;
    case CmsSectionType.editorialIntro:
    case CmsSectionType.seoText:
    case CmsSectionType.discoverLinks:
    case CmsSectionType.brandSegment:
      return false;
  }
}

class CmsSectionEditorDialog extends ConsumerStatefulWidget {
  final CmsSectionEditorRequest request;

  const CmsSectionEditorDialog({super.key, required this.request});

  static Future<bool?> show(
    BuildContext context, {
    required CmsSectionEditorRequest request,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CmsSectionEditorDialog(request: request),
    );
  }

  @override
  ConsumerState<CmsSectionEditorDialog> createState() =>
      _CmsSectionEditorDialogState();
}

class _CmsSectionEditorDialogState extends ConsumerState<CmsSectionEditorDialog>
    with SingleTickerProviderStateMixin {
  /// Canonical config for the section. Both views read and write here.
  late Map<String, dynamic> _config;

  /// JSON buffer — only synced from `_config` when the JSON tab becomes
  /// active, and parsed back into `_config` when the user leaves it or saves.
  late TextEditingController _jsonController;

  TabController? _tabController;
  bool _hasForm = false;
  String? _validationError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = Map<String, dynamic>.from(
      widget.request.isCreate
          ? defaultConfigFor(widget.request.type)
          : widget.request.initialConfig!,
    );
    _jsonController = TextEditingController(text: _prettyJson(_config));
    _hasForm = _hasFormView(widget.request.type);
    if (_hasForm) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  String _prettyJson(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  void _onTabChanged() {
    final controller = _tabController;
    if (controller == null) return;
    // Only react when the index actually changes, not during the animation.
    if (controller.indexIsChanging) return;
    final isMovingToJson =
        controller.previousIndex == 0 && controller.index == 1;
    final isMovingToForm =
        controller.previousIndex == 1 && controller.index == 0;

    if (isMovingToJson) {
      // Form-edited config -> refresh JSON buffer.
      _jsonController.text = _prettyJson(_config);
      _jsonController.selection = TextSelection.collapsed(
        offset: _jsonController.text.length,
      );
      setState(() => _validationError = null);
      return;
    }

    if (isMovingToForm) {
      final parsed = _tryParseJson();
      if (parsed == null) {
        setState(() {
          _validationError =
              'JSON invalide — corrigez-le avant de revenir au formulaire.';
        });
        // Cancel the tab move.
        controller.animateTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'JSON invalide. Réparez-le pour revenir au formulaire.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _config = parsed;
        _validationError = null;
      });
    }
  }

  /// Returns the parsed JSON or null if invalid. No side effects.
  Map<String, dynamic>? _tryParseJson() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Same as [_tryParseJson] but surfaces a validation error in the UI.
  Map<String, dynamic>? _parseJsonForSave() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      if (decoded is! Map) {
        setState(() => _validationError = 'Le JSON doit être un objet.');
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      setState(() => _validationError = 'JSON invalide : $e');
      return null;
    }
  }

  bool get _isJsonTabActive {
    final c = _tabController;
    if (c == null) return true; // form-less section types are JSON only.
    return c.index == 1;
  }

  /// Form view callback: replace `_config` with the form's snapshot.
  void _onFormConfigChanged(Map<String, dynamic> next) {
    _config = next;
  }

  Future<void> _onInsertMedia() async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !mounted) return;

    final config = _tryParseJson();
    final slots = config != null ? _findMediaSlots(config) : const <String>[];

    String? targetSlot;
    if (slots.isNotEmpty) {
      targetSlot = await _pickMediaSlot(slots);
      if (targetSlot == null || !mounted) return;
    }

    final result = await MediaPickerModal.show(context, authToken: token);
    if (result == null || !mounted) return;

    final mediaMap = <String, dynamic>{
      'recordId': result.media.id,
      'collectionId': result.media.collectionId,
      'filename': result.media.file,
      'alt': result.media.altText,
    };

    if (targetSlot != null && targetSlot != '__cursor__' && config != null) {
      config[targetSlot] = mediaMap;
      if (config.containsKey('mediaType') &&
          isVideoFilename(result.media.file)) {
        config['mediaType'] = 'video';
      }
      _jsonController.text = _prettyJson(config);
      _jsonController.selection = TextSelection.collapsed(
        offset: _jsonController.text.length,
      );
      return;
    }

    _insertAtCursor(_prettyJson(mediaMap));
  }

  List<String> _findMediaSlots(Map<String, dynamic> config) {
    return config.keys.where((k) {
      if (k == 'mediaType') return false;
      if (!k.toLowerCase().startsWith('media')) return false;
      final v = config[k];
      return v == null || v is Map;
    }).toList();
  }

  Future<String?> _pickMediaSlot(List<String> slots) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Insérer le média dans'),
        children: [
          for (final s in slots)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(s),
              child: Text(s),
            ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('__cursor__'),
            child: const Text('Insérer au curseur (avancé)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _insertAtCursor(String text) {
    final selection = _jsonController.selection;
    final base = _jsonController.text;
    if (!selection.isValid) {
      _jsonController.text = '$base\n$text';
      _jsonController.selection = TextSelection.collapsed(
        offset: _jsonController.text.length,
      );
      return;
    }
    final newText = base.replaceRange(selection.start, selection.end, text);
    _jsonController.text = newText;
    _jsonController.selection = TextSelection.collapsed(
      offset: selection.start + text.length,
    );
  }

  Future<void> _onSave() async {
    setState(() {
      _validationError = null;
      _saving = true;
    });

    Map<String, dynamic>? config;
    if (_isJsonTabActive) {
      config = _parseJsonForSave();
    } else {
      // Form view drives _config directly via onChanged.
      config = Map<String, dynamic>.from(_config);
    }

    if (config == null) {
      setState(() => _saving = false);
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null) {
      setState(() => _saving = false);
      return;
    }

    final controller = ref.read(cmsPageEditorControllerProvider.notifier);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (widget.request.isCreate) {
        await controller.createSection(
          pageId: widget.request.pageId,
          sectionId: widget.request.proposedSectionId!,
          type: widget.request.type,
          position: widget.request.position,
          config: config,
        );
      } else {
        await controller.updateSectionConfig(
          sectionRecordId: widget.request.sectionRecordId!,
          config: config,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Section sauvegardée.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _validationError = 'Échec de la sauvegarde : $error';
      });
    }
  }

  Widget _buildFormView() {
    switch (widget.request.type) {
      case CmsSectionType.heroCampaign:
        return HeroCampaignForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.editorialStory:
        return EditorialStoryForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.categoryTiles:
        return CategoryTilesForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.featuredProducts:
        return FeaturedProductsForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.serviceCards:
        return ServiceCardsForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.collectionHero:
        return CollectionHeroForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.mixedProductGrid:
        return MixedProductGridForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.horizontalTileCarousel:
        return HorizontalTileCarouselForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.categoryBannerStrip:
        return CategoryBannerStripForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.categorySplitTabs:
        return CategorySplitTabsForm(
          initialConfig: _config,
          enabled: !_saving,
          onChanged: _onFormConfigChanged,
        );
      case CmsSectionType.editorialIntro:
      case CmsSectionType.seoText:
      case CmsSectionType.discoverLinks:
      case CmsSectionType.brandSegment:
        return const SizedBox.shrink();
    }
  }

  Widget _buildJsonView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _onInsertMedia,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Insérer un média'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
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
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              errorText: _validationError,
            ),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\t'))],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.9).clamp(360.0, 760.0);
    final height = (size.height * 0.9).clamp(480.0, 760.0);
    final typeLabel = sectionTypeLabel(widget.request.type);

    final body = _hasForm
        ? Column(
            children: [
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
            ],
          )
        : _buildJsonView();

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
                      widget.request.isCreate
                          ? 'Ajouter — $typeLabel'
                          : 'Éditer — $typeLabel',
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
              Expanded(child: body),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _onSave,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Sauvegarde…' : 'Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
