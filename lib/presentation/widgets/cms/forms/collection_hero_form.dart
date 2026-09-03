import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';
import 'cms_form_fields.dart';
import 'cms_media_slot_field.dart';

class CollectionHeroForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const CollectionHeroForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CollectionHeroForm> createState() => _CollectionHeroFormState();
}

class _CollectionHeroFormState extends State<CollectionHeroForm> {
  late TextEditingController _title;
  late TextEditingController _intro;
  late TextEditingController _aspectRatio;
  late String _mobileLayout;
  late String _desktopLayout;
  CmsMediaRef? _imageMobile;
  CmsMediaRef? _imageDesktop;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant CollectionHeroForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    _title = TextEditingController(text: cmsStringValue(config['title']));
    _intro = TextEditingController(text: cmsStringValue(config['intro']));
    _aspectRatio = TextEditingController(
      text: cmsStringValue(config['aspectRatio']).isEmpty
          ? '4/5'
          : cmsStringValue(config['aspectRatio']),
    );
    _mobileLayout = cmsNormalizeOption(
      config['mobileLayout'],
      const ['imageTop', 'textOnly'],
      'imageTop',
      caseSensitive: true,
    );
    _desktopLayout = cmsNormalizeOption(
      config['desktopLayout'],
      const ['split', 'centered', 'imageTop'],
      'split',
      caseSensitive: true,
    );
    _imageMobile = CmsMediaRef.maybeFromJson(config['imageMobile']);
    _imageDesktop = CmsMediaRef.maybeFromJson(config['imageDesktop']);
    for (final controller in [_title, _intro, _aspectRatio]) {
      controller.addListener(_emit);
    }
  }

  void _disposeControllers() {
    for (final controller in [_title, _intro, _aspectRatio]) {
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
      'schemaVersion': 1,
      'title': _title.text.trim(),
      'intro': cmsTrimToNull(_intro.text),
      'imageMobile': cmsMediaMap(_imageMobile),
      'imageDesktop': cmsMediaMap(_imageDesktop),
      'mobileLayout': _mobileLayout,
      'desktopLayout': _desktopLayout,
      'aspectRatio': cmsTrimToNull(_aspectRatio.text) ?? '4/5',
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
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _intro,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Introduction',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Médias'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CmsMediaSlotField(
                      label: 'Image mobile',
                      value: _imageMobile,
                      onChanged: (media) {
                        setState(() => _imageMobile = media);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CmsMediaSlotField(
                      label: 'Image desktop',
                      value: _imageDesktop,
                      onChanged: (media) {
                        setState(() => _imageDesktop = media);
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Mise en page'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _mobileLayout,
                      decoration: const InputDecoration(
                        labelText: 'Layout mobile',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'imageTop',
                          child: Text('Image au-dessus'),
                        ),
                        DropdownMenuItem(
                          value: 'textOnly',
                          child: Text('Texte seul'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _mobileLayout = value);
                        _emit();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _desktopLayout,
                      decoration: const InputDecoration(
                        labelText: 'Layout desktop',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'split', child: Text('Split')),
                        DropdownMenuItem(
                          value: 'centered',
                          child: Text('Centré'),
                        ),
                        DropdownMenuItem(
                          value: 'imageTop',
                          child: Text('Image au-dessus'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _desktopLayout = value);
                        _emit();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aspectRatio,
                decoration: const InputDecoration(
                  labelText: 'Ratio image',
                  helperText: 'Exemples: 4/5, 16/9, 1/1',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
