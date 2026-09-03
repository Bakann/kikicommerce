import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../application/catalog/pdp_localized_text_editor.dart';
import '../../../core/constants.dart';
import '../product_detail_layout_spec.dart';

const kPdpTranslationsEditorSemanticsLabel = 'Modifier les traductions PDP';
const kPdpTranslationsEditorSemanticsIdentifier =
    'pdp-translations-editor-trigger';

class PdpTranslationsEditorSheet extends ConsumerStatefulWidget {
  final String productId;
  final String authToken;
  final String initialLocale;

  const PdpTranslationsEditorSheet({
    super.key,
    required this.productId,
    required this.authToken,
    required this.initialLocale,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String productId,
    required String authToken,
    required String initialLocale,
  }) {
    final layout = ProductDetailLayoutSpec.forWidth(
      MediaQuery.sizeOf(context).width,
    );
    final child = PdpTranslationsEditorSheet(
      productId: productId,
      authToken: authToken,
      initialLocale: initialLocale,
    );

    if (layout.isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.92,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: child,
            ),
          );
        },
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<PdpTranslationsEditorSheet> createState() =>
      _PdpTranslationsEditorSheetState();
}

class _PdpTranslationsEditorSheetState
    extends ConsumerState<PdpTranslationsEditorSheet> {
  late final Future<PdpLocalizedTextBundle> _loadFuture;
  int _selectedIndex = 0;
  bool _isSaving = false;
  String? _errorText;
  PdpLocalizedTextBundle? _bundle;
  _ProductTextControllers? _frProduct;
  _ProductTextControllers? _enProduct;
  final Map<String, _ChapterTextControllers> _frChapters = {};
  final Map<String, _ChapterTextControllers> _enChapters = {};

  String get _selectedLocale =>
      _selectedIndex == 0 ? pdpBaseLocale : pdpTranslationLocale;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialLocale == pdpTranslationLocale ? 1 : 0;
    _loadFuture = ref.read(loadPdpLocalizedTextProvider)(
      baseUrl: ref.read(apiBaseUrlProvider),
      authToken: widget.authToken,
      productId: widget.productId,
    );
  }

  @override
  void dispose() {
    _frProduct?.dispose();
    _enProduct?.dispose();
    for (final controller in _frChapters.values) {
      controller.dispose();
    }
    for (final controller in _enChapters.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(PdpLocalizedTextBundle bundle) {
    if (_bundle != null) return;
    _bundle = bundle;
    _frProduct = _ProductTextControllers.fromProduct(bundle.baseProduct)
      ..addListener(_handleChanged);
    _enProduct = _ProductTextControllers.fromProduct(bundle.translationProduct)
      ..addListener(_handleChanged);
    for (final chapter in bundle.chapters) {
      _frChapters[chapter.id] = _ChapterTextControllers.fromChapter(
        chapter.base,
      )..addListener(_handleChanged);
      _enChapters[chapter.id] = _ChapterTextControllers.fromChapter(
        chapter.translation,
      )..addListener(_handleChanged);
    }
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasAnyChanges =>
      _hasChanges(pdpBaseLocale) || _hasChanges(pdpTranslationLocale);

  bool _hasChanges(String locale) {
    final bundle = _bundle;
    if (bundle == null) return false;
    if (locale == pdpBaseLocale) {
      return _productChanged(bundle.baseProduct, _frProduct!) ||
          bundle.chapters.any(
            (chapter) =>
                _chapterChanged(chapter.base, _frChapters[chapter.id]!),
          );
    }
    return _productChanged(bundle.translationProduct, _enProduct!) ||
        bundle.chapters.any(
          (chapter) =>
              _chapterChanged(chapter.translation, _enChapters[chapter.id]!),
        );
  }

  Future<void> _save() async {
    final bundle = _bundle;
    if (bundle == null || _isSaving || !_hasAnyChanges) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    // Persist every locale that has pending edits — not just the active tab —
    // so switching tabs before saving never silently drops the other locale's
    // changes when the sheet closes on success.
    var savedAny = false;
    for (final locale in const [pdpBaseLocale, pdpTranslationLocale]) {
      if (!_hasChanges(locale)) continue;
      final result = await ref.read(savePdpLocalizedTextProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: widget.authToken,
        initial: bundle,
        locale: locale,
        draft: _draftFor(locale),
      );
      if (!mounted) return;
      switch (result) {
        case SavePdpLocalizedTextSaved():
          savedAny = true;
        case SavePdpLocalizedTextNoChange():
          break;
        case SavePdpLocalizedTextValidationFailure(:final message):
          setState(() {
            _isSaving = false;
            _errorText = message;
            _selectedIndex = locale == pdpBaseLocale ? 0 : 1;
          });
          return;
        case SavePdpLocalizedTextFailure(:final error):
          setState(() {
            _isSaving = false;
            _errorText = 'Erreur lors de la sauvegarde: $error';
          });
          return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(savedAny);
  }

  PdpLocalizedTextDraft _draftFor(String locale) {
    final product = locale == pdpBaseLocale ? _frProduct! : _enProduct!;
    final chapters = locale == pdpBaseLocale ? _frChapters : _enChapters;
    return PdpLocalizedTextDraft(
      product: product.toProduct(),
      chapters: [
        for (final entry in chapters.entries)
          entry.value.toChapter(chapterId: entry.key),
      ],
    );
  }

  void _copyFrToEn() {
    final frProduct = _frProduct;
    final enProduct = _enProduct;
    if (frProduct == null || enProduct == null) return;
    enProduct.setFrom(frProduct);
    for (final entry in _frChapters.entries) {
      _enChapters[entry.key]?.setFrom(entry.value);
    }
    setState(() {
      _selectedIndex = 1;
      _errorText = null;
    });
  }

  void _clearEn() {
    _enProduct?.clear();
    for (final controller in _enChapters.values) {
      controller.clear();
    }
    setState(() {
      _selectedIndex = 1;
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PdpLocalizedTextBundle>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          _initializeControllers(data);
        }

        return DefaultTabController(
          key: ValueKey(_selectedIndex),
          length: 2,
          initialIndex: _selectedIndex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(
                isLoading: snapshot.connectionState != ConnectionState.done,
              ),
              if (snapshot.hasError)
                Expanded(child: _ErrorState(error: snapshot.error))
              else if (data == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                TabBar(
                  onTap: (index) => setState(() => _selectedIndex = index),
                  labelColor: kNavyBlue,
                  unselectedLabelColor: const Color(0xFF70757A),
                  indicatorColor: kNavyBlue,
                  tabs: const [
                    Tab(text: 'FR'),
                    Tab(text: 'EN'),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: _buildLocalePane(data, _selectedLocale),
                  ),
                ),
                _buildActions(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalePane(PdpLocalizedTextBundle bundle, String locale) {
    final isBase = locale == pdpBaseLocale;
    final product = isBase ? _frProduct! : _enProduct!;
    final chapters = isBase ? _frChapters : _enChapters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusPill(label: _statusLabel(bundle, locale)),
            if (!isBase)
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _copyFrToEn,
                icon: const Icon(Icons.content_copy_outlined, size: 18),
                label: const Text('Copier depuis FR'),
              ),
            if (!isBase)
              TextButton.icon(
                onPressed: _isSaving ? null : _clearEn,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Supprimer la traduction EN'),
              ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 14),
          Text(
            _errorText!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        _LocalizedTextField(
          controller: product.name,
          label: 'Nom produit',
          requiredLabel: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _LocalizedTextField(
          controller: product.summary,
          label: 'Résumé',
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 14),
        _LocalizedTextField(
          controller: product.description,
          label: 'Description',
          minLines: 5,
          maxLines: 10,
        ),
        if (bundle.chapters.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text(
            'Narrative PDP',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: kNavyBlue,
            ),
          ),
          const SizedBox(height: 12),
          for (final chapter in bundle.chapters) ...[
            _ChapterEditor(
              label: 'Chapitre ${chapter.position + 1}',
              controllers: chapters[chapter.id]!,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ],
    );
  }

  Widget _buildActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          children: [
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _isSaving || !_hasAnyChanges ? null : _save,
              child: _isSaving
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
      ),
    );
  }

  String _statusLabel(PdpLocalizedTextBundle bundle, String locale) {
    if (_hasChanges(locale)) return 'Modifié non enregistré';
    if (locale == pdpTranslationLocale && !bundle.hasAnyTranslation) {
      return 'Utilise le FR';
    }
    return 'Publié';
  }

  bool _productChanged(
    PdpLocalizedProductText before,
    _ProductTextControllers after,
  ) {
    return after.name.text.trim() != before.name.trim() ||
        after.summary.text.trim() != before.summary.trim() ||
        after.description.text.trim() != before.description.trim();
  }

  bool _chapterChanged(
    PdpLocalizedChapterText before,
    _ChapterTextControllers after,
  ) {
    return after.headline.text.trim() != before.headline.trim() ||
        after.story.text.trim() != before.story.trim() ||
        after.ctaLabel.text.trim() != before.ctaLabel.trim();
  }
}

class _SheetHeader extends StatelessWidget {
  final bool isLoading;

  const _SheetHeader({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Traductions PDP',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2A2A28),
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Impossible de charger les traductions: $error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDirty = label == 'Modifié non enregistré';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDirty ? const Color(0xFFFFF7E8) : const Color(0xFFEFF5F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDirty ? const Color(0xFFE8B66D) : const Color(0xFFBBD5C8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: isDirty ? const Color(0xFF8A5A10) : const Color(0xFF2F6450),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LocalizedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool requiredLabel;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  const _LocalizedTextField({
    required this.controller,
    required this.label,
    this.requiredLabel = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: requiredLabel ? '$label *' : label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _ChapterEditor extends StatelessWidget {
  final String label;
  final _ChapterTextControllers controllers;

  const _ChapterEditor({required this.label, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E0D8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A3A34),
              ),
            ),
            const SizedBox(height: 12),
            _LocalizedTextField(
              controller: controllers.headline,
              label: 'Titre chapitre',
              requiredLabel: true,
            ),
            const SizedBox(height: 12),
            _LocalizedTextField(
              controller: controllers.story,
              label: 'Récit',
              minLines: 4,
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            _LocalizedTextField(
              controller: controllers.ctaLabel,
              label: 'Libellé CTA',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTextControllers {
  final TextEditingController name;
  final TextEditingController summary;
  final TextEditingController description;

  _ProductTextControllers({
    required String name,
    required String summary,
    required String description,
  }) : name = TextEditingController(text: name),
       summary = TextEditingController(text: summary),
       description = TextEditingController(text: description);

  factory _ProductTextControllers.fromProduct(PdpLocalizedProductText text) {
    return _ProductTextControllers(
      name: text.name,
      summary: text.summary,
      description: text.description,
    );
  }

  void addListener(VoidCallback listener) {
    name.addListener(listener);
    summary.addListener(listener);
    description.addListener(listener);
  }

  void setFrom(_ProductTextControllers other) {
    name.text = other.name.text;
    summary.text = other.summary.text;
    description.text = other.description.text;
  }

  void clear() {
    name.clear();
    summary.clear();
    description.clear();
  }

  PdpLocalizedProductText toProduct() {
    return PdpLocalizedProductText(
      name: name.text,
      summary: summary.text,
      description: description.text,
    );
  }

  void dispose() {
    name.dispose();
    summary.dispose();
    description.dispose();
  }
}

class _ChapterTextControllers {
  final TextEditingController headline;
  final TextEditingController story;
  final TextEditingController ctaLabel;

  _ChapterTextControllers({
    required String headline,
    required String story,
    required String ctaLabel,
  }) : headline = TextEditingController(text: headline),
       story = TextEditingController(text: story),
       ctaLabel = TextEditingController(text: ctaLabel);

  factory _ChapterTextControllers.fromChapter(PdpLocalizedChapterText text) {
    return _ChapterTextControllers(
      headline: text.headline,
      story: text.story,
      ctaLabel: text.ctaLabel,
    );
  }

  void addListener(VoidCallback listener) {
    headline.addListener(listener);
    story.addListener(listener);
    ctaLabel.addListener(listener);
  }

  void setFrom(_ChapterTextControllers other) {
    headline.text = other.headline.text;
    story.text = other.story.text;
    ctaLabel.text = other.ctaLabel.text;
  }

  void clear() {
    headline.clear();
    story.clear();
    ctaLabel.clear();
  }

  PdpLocalizedChapterText toChapter({required String chapterId}) {
    return PdpLocalizedChapterText(
      chapterId: chapterId,
      headline: headline.text,
      story: story.text,
      ctaLabel: ctaLabel.text,
    );
  }

  void dispose() {
    headline.dispose();
    story.dispose();
    ctaLabel.dispose();
  }
}
