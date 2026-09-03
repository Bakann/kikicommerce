import 'package:flutter/material.dart';

import 'cms_form_fields.dart';

const List<String> kFeaturedProductLayouts = ['grid2', 'grid3', 'grid4'];

class FeaturedProductsForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const FeaturedProductsForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<FeaturedProductsForm> createState() => _FeaturedProductsFormState();
}

class _FeaturedProductsFormState extends State<FeaturedProductsForm> {
  late TextEditingController _eyebrow;
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late TextEditingController _ctaLabel;
  late TextEditingController _ctaHref;
  late List<dynamic> _productIds;
  late String _layout;
  late bool _showPrices;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant FeaturedProductsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    final cta = config['primaryCta'] is Map
        ? Map<String, dynamic>.from(config['primaryCta'] as Map)
        : const <String, dynamic>{};
    _eyebrow = TextEditingController(text: cmsStringValue(config['eyebrow']));
    _title = TextEditingController(text: cmsStringValue(config['title']));
    _subtitle = TextEditingController(text: cmsStringValue(config['subtitle']));
    _ctaLabel = TextEditingController(text: cmsStringValue(cta['label']));
    _ctaHref = TextEditingController(text: cmsStringValue(cta['href']));
    for (final controller in [
      _eyebrow,
      _title,
      _subtitle,
      _ctaLabel,
      _ctaHref,
    ]) {
      controller.addListener(_emit);
    }
    _productIds = cmsListValue(config['productIds']);
    _layout = cmsNormalizeOption(
      config['layout'],
      kFeaturedProductLayouts,
      'grid4',
    );
    _showPrices = config['showPrices'] as bool? ?? true;
  }

  void _disposeControllers() {
    for (final controller in [
      _eyebrow,
      _title,
      _subtitle,
      _ctaLabel,
      _ctaHref,
    ]) {
      controller.removeListener(_emit);
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Map<String, dynamic> _buildConfig() {
    return <String, dynamic>{
      'eyebrow': cmsTrimToNull(_eyebrow.text),
      'title': cmsTrimToNull(_title.text),
      'subtitle': cmsTrimToNull(_subtitle.text),
      'primaryCta': cmsCtaMap(label: _ctaLabel.text, href: _ctaHref.text),
      'productIds': _productIds,
      'layout': _layout,
      'showPrices': _showPrices,
    };
  }

  void _emit() {
    widget.onChanged(_buildConfig());
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
                controller: _eyebrow,
                decoration: const InputDecoration(
                  labelText: 'Eyebrow',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
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
              const CmsFormSectionHeader(label: 'Bouton principal'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctaLabel,
                      decoration: const InputDecoration(
                        labelText: 'Libellé',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctaHref,
                      decoration: const InputDecoration(
                        labelText: 'Lien (ex: /catalog)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Produits'),
              const SizedBox(height: 12),
              CmsJsonArrayField(
                label: 'productIds JSON',
                initialValue: _productIds,
                enabled: widget.enabled,
                helperText:
                    'Tableau JSON d\'IDs produits, dans l\'ordre voulu.',
                onChanged: (next) {
                  _productIds = next;
                  _emit();
                },
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Mise en page'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _layout,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Layout',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final value in kFeaturedProductLayouts)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _layout = value);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      value: _showPrices,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _showPrices = value);
                        _emit();
                      },
                      title: const Text('Afficher les prix'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
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
