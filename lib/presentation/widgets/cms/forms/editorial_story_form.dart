import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/cms/cms_models.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

const List<String> kEditorialMediaTypes = ['image', 'video', 'none'];
const List<String> kEditorialLayoutVariants = [
  'mediaLeft',
  'mediaRight',
  'mediaTop',
  'mediaBottom',
];
const List<String> kEditorialBackgroundTones = ['light', 'sand', 'dark'];

/// Structured form for `editorial_story` sections. Pushes a snapshot of the
/// resulting config to [onChanged] on every edit. The parent (dialog) owns
/// the canonical config map and is responsible for forwarding it on save.
class EditorialStoryForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const EditorialStoryForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  ConsumerState<EditorialStoryForm> createState() => _EditorialStoryFormState();
}

class _EditorialStoryFormState extends ConsumerState<EditorialStoryForm> {
  late TextEditingController _eyebrow;
  late TextEditingController _title;
  late TextEditingController _body;
  late TextEditingController _ctaLabel;
  late TextEditingController _ctaHref;

  CmsMediaRef? _mediaDesktop;
  CmsMediaRef? _mediaMobile;
  late String _mediaType;
  late String _layoutVariant;
  late String _backgroundTone;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant EditorialStoryForm oldWidget) {
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
    _body = TextEditingController(text: cmsStringValue(config['body']));
    _ctaLabel = TextEditingController(text: cmsStringValue(cta['label']));
    _ctaHref = TextEditingController(text: cmsStringValue(cta['href']));
    for (final c in [_eyebrow, _title, _body, _ctaLabel, _ctaHref]) {
      c.addListener(_emit);
    }

    _mediaDesktop = CmsMediaRef.maybeFromJson(config['mediaDesktop']);
    _mediaMobile = CmsMediaRef.maybeFromJson(config['mediaMobile']);
    _mediaType = cmsNormalizeOption(
      config['mediaType'],
      kEditorialMediaTypes,
      'image',
    );
    _layoutVariant = cmsNormalizeOption(
      config['layoutVariant'],
      kEditorialLayoutVariants,
      'mediaTop',
      caseSensitive: true,
    );
    _backgroundTone = cmsNormalizeOption(
      config['backgroundTone'],
      kEditorialBackgroundTones,
      'light',
    );
  }

  void _disposeControllers() {
    for (final c in [_eyebrow, _title, _body, _ctaLabel, _ctaHref]) {
      c.removeListener(_emit);
      c.dispose();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  String? _trimToNull(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic>? _ctaMap() {
    final label = _trimToNull(_ctaLabel.text);
    final href = _trimToNull(_ctaHref.text);
    if (label == null && href == null) return null;
    return <String, dynamic>{'label': ?label, 'href': ?href};
  }

  Map<String, dynamic>? _mediaMap(CmsMediaRef? ref) {
    if (ref == null) return null;
    return <String, dynamic>{
      'recordId': ref.recordId,
      'collectionId': ref.collectionId,
      'filename': ref.filename,
      'alt': ?ref.alt,
    };
  }

  Map<String, dynamic> _buildConfig() {
    return <String, dynamic>{
      'eyebrow': _trimToNull(_eyebrow.text),
      'title': _title.text.trim(),
      'body': _trimToNull(_body.text),
      'primaryCta': _ctaMap(),
      'mediaDesktop': _mediaMap(_mediaDesktop),
      'mediaMobile': _mediaMap(_mediaMobile),
      'mediaType': _mediaType,
      'layoutVariant': _layoutVariant,
      'backgroundTone': _backgroundTone,
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
      // Auto-promote mediaType to 'video' if either slot is a video.
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
              _SectionHeader(label: 'Texte'),
              const SizedBox(height: 12),
              TextField(
                controller: _eyebrow,
                decoration: const InputDecoration(
                  labelText: 'Eyebrow (court, ex: « DIOR WORLD »)',
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
                controller: _body,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Texte éditorial',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(label: 'Bouton principal'),
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
              _SectionHeader(label: 'Médias'),
              const SizedBox(height: 12),
              mediaSlots,
              const SizedBox(height: 24),
              _SectionHeader(label: 'Mise en page'),
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
                        for (final v in kEditorialMediaTypes)
                          DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _mediaType = v);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _layoutVariant,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Disposition',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final v in kEditorialLayoutVariants)
                          DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _layoutVariant = v);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _backgroundTone,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fond',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final v in kEditorialBackgroundTones)
                          DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _backgroundTone = v);
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

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Color(0xFF6F6F6F),
      ),
    );
  }
}
