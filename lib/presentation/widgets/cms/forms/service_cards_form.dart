import 'package:flutter/material.dart';

import 'cms_form_fields.dart';

class ServiceCardsForm extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final bool enabled;

  const ServiceCardsForm({
    super.key,
    required this.initialConfig,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<ServiceCardsForm> createState() => _ServiceCardsFormState();
}

class _ServiceCardsFormState extends State<ServiceCardsForm> {
  late TextEditingController _title;
  late List<dynamic> _cards;

  @override
  void initState() {
    super.initState();
    _hydrate(widget.initialConfig);
  }

  @override
  void didUpdateWidget(covariant ServiceCardsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.initialConfig, widget.initialConfig)) {
      _disposeControllers();
      _hydrate(widget.initialConfig);
    }
  }

  void _hydrate(Map<String, dynamic> config) {
    _title = TextEditingController(text: cmsStringValue(config['title']));
    _title.addListener(_emit);
    _cards = cmsListValue(config['cards']);
  }

  void _disposeControllers() {
    _title.removeListener(_emit);
    _title.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  Map<String, dynamic> _buildConfig() {
    return <String, dynamic>{
      'title': cmsTrimToNull(_title.text),
      'cards': _cards,
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
              const SizedBox(height: 24),
              const CmsFormSectionHeader(label: 'Cartes'),
              const SizedBox(height: 12),
              CmsJsonArrayField(
                label: 'cards JSON',
                initialValue: _cards,
                enabled: widget.enabled,
                helperText:
                    'Tableau JSON. Chaque carte attend au minimum title et href.',
                onChanged: (next) {
                  _cards = next;
                  _emit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
