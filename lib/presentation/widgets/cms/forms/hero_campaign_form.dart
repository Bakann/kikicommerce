import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/cms/cms_models.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

const List<String> kHeroMediaTypes = ['image', 'video', 'none'];
const List<String> kHeroTextAlignments = ['left', 'center', 'right'];
// 'square' renders a full-bleed 1:1 hero — used by the category PLP hero.
const List<String> kHeroHeightModes = ['sm', 'md', 'lg', 'xl', 'square'];

class HeroCampaignForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const HeroCampaignForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  ConsumerState<HeroCampaignForm> createState() => _HeroCampaignFormState();
}

class _HeroCampaignFormState extends ConsumerState<HeroCampaignForm> {
  late TextEditingController _eyebrow;
  late TextEditingController _title;
  late TextEditingController _subtitle;
  late TextEditingController _body;
  late TextEditingController _ctaLabel;
  late TextEditingController _ctaHref;

  CmsMediaRef? _mediaDesktop;
  CmsMediaRef? _mediaMobile;
  late String _mediaType;
  late String _textAlign;
  late String _heightMode;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant HeroCampaignForm oldWidget) {
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
    _body = TextEditingController(text: cmsStringValue(config['body']));
    _ctaLabel = TextEditingController(text: cmsStringValue(cta['label']));
    _ctaHref = TextEditingController(text: cmsStringValue(cta['href']));
    for (final controller in [
      _eyebrow,
      _title,
      _subtitle,
      _body,
      _ctaLabel,
      _ctaHref,
    ]) {
      controller.addListener(_emit);
    }

    _mediaDesktop = CmsMediaRef.maybeFromJson(config['mediaDesktop']);
    _mediaMobile = CmsMediaRef.maybeFromJson(config['mediaMobile']);
    _mediaType = cmsNormalizeOption(
      config['mediaType'],
      kHeroMediaTypes,
      'image',
    );
    _textAlign = cmsNormalizeOption(
      config['textAlign'],
      kHeroTextAlignments,
      'center',
    );
    _heightMode = cmsNormalizeOption(
      config['heightMode'],
      kHeroHeightModes,
      'xl',
    );
  }

  void _disposeControllers() {
    for (final controller in [
      _eyebrow,
      _title,
      _subtitle,
      _body,
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
      'title': _title.text.trim(),
      'subtitle': cmsTrimToNull(_subtitle.text),
      'body': cmsTrimToNull(_body.text),
      'primaryCta': cmsCtaMap(label: _ctaLabel.text, href: _ctaHref.text),
      'mediaDesktop': cmsMediaMap(_mediaDesktop),
      'mediaMobile': cmsMediaMap(_mediaMobile),
      'mediaType': _mediaType,
      'textAlign': _textAlign,
      'heightMode': _heightMode,
    };
  }

  void _emit() {
    widget.onChanged(_buildConfig());
  }

  void _onMediaChanged(bool isDesktop, CmsMediaRef? next) {
    setState(() {
      if (isDesktop) {
        _mediaDesktop = next;
      } else {
        _mediaMobile = next;
      }
      if (next != null && next.isVideo) {
        _mediaType = 'video';
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useTwoColumns = width > 720;

    final mediaSlots = useTwoColumns
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CmsMediaSlotField(
                  label: 'Image / vidéo desktop',
                  value: _mediaDesktop,
                  onChanged: (next) => _onMediaChanged(true, next),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CmsMediaSlotField(
                  label: 'Image / vidéo mobile',
                  value: _mediaMobile,
                  onChanged: (next) => _onMediaChanged(false, next),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CmsMediaSlotField(
                label: 'Image / vidéo desktop',
                value: _mediaDesktop,
                onChanged: (next) => _onMediaChanged(true, next),
              ),
              const SizedBox(height: 16),
              CmsMediaSlotField(
                label: 'Image / vidéo mobile',
                value: _mediaMobile,
                onChanged: (next) => _onMediaChanged(false, next),
              ),
            ],
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
                  labelText: 'Titre *',
                  helperText: 'Champ requis',
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
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Texte court',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
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
              const CmsFormSectionHeader(label: 'Médias'),
              const SizedBox(height: 12),
              mediaSlots,
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Mise en page'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _mediaType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Type de média',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final value in kHeroMediaTypes)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _mediaType = value);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _textAlign,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Alignement texte',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final value in kHeroTextAlignments)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _textAlign = value);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _heightMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hauteur',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final value in kHeroHeightModes)
                          DropdownMenuItem(value: value, child: Text(value)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _heightMode = value);
                        _emit();
                      },
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
