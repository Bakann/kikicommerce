import 'package:flutter/material.dart';

import '../../application/admin/validate_admin_record.dart';
import '../admin_collection_schema.dart';
import 'admin_field_builder.dart';

class AdminRecordDraft {
  final Map<String, dynamic> data;
  final String? mediaSource;

  const AdminRecordDraft({required this.data, this.mediaSource});
}

class AdminRecordEditorDialog extends StatefulWidget {
  final AdminCollectionDefinition definition;
  final Map<String, dynamic>? record;
  final Map<String, List<Map<String, dynamic>>> relationData;

  const AdminRecordEditorDialog({
    super.key,
    required this.definition,
    required this.record,
    required this.relationData,
  });

  @override
  State<AdminRecordEditorDialog> createState() =>
      _AdminRecordEditorDialogState();
}

class _AdminRecordEditorDialogState extends State<AdminRecordEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, String?> _singleRelationValues = {};
  final Map<String, Set<String>> _multiRelationValues = {};
  final Map<String, String?> _selectValues = {};
  final TextEditingController _mediaSourceController = TextEditingController();
  String? _validationError;

  @override
  void initState() {
    super.initState();
    for (final field in widget.definition.fields) {
      final rawValue = widget.record?[field.name];
      switch (field.type) {
        case AdminFieldType.boolean:
          _boolValues[field.name] = rawValue as bool? ?? true;
          break;
        case AdminFieldType.relationSingle:
          _singleRelationValues[field.name] = rawValue as String?;
          break;
        case AdminFieldType.relationMultiple:
          final values = (rawValue as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toSet();
          _multiRelationValues[field.name] = values;
          break;
        case AdminFieldType.select:
          _selectValues[field.name] = rawValue as String?;
          break;
        case AdminFieldType.file:
          _controllers[field.name] = TextEditingController(
            text: rawValue?.toString() ?? '',
          );
          break;
        case AdminFieldType.text:
        case AdminFieldType.multiline:
        case AdminFieldType.integer:
        case AdminFieldType.decimal:
        case AdminFieldType.dateTime:
          _controllers[field.name] = TextEditingController(
            text: rawValue?.toString() ?? '',
          );
          break;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _mediaSourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${isEditing ? 'Éditer' : 'Créer'} ${widget.definition.label}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.record != null)
                SelectableText('id: ${widget.record!['id']}'),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final field in widget.definition.fields)
                          SizedBox(
                            width:
                                field.type == AdminFieldType.multiline ||
                                    field.type ==
                                        AdminFieldType.relationMultiple
                                ? 820
                                : 390,
                            child: _buildField(field),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_validationError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(AdminFieldDefinition field) {
    switch (field.type) {
      case AdminFieldType.boolean:
        return AdminBooleanField(
          field: field,
          value: _boolValues[field.name] ?? true,
          onChanged: (value) => setState(() => _boolValues[field.name] = value),
        );
      case AdminFieldType.relationSingle:
        return AdminSingleRelationField(
          field: field,
          value: _singleRelationValues[field.name],
          records: widget.relationData[field.relationCollection] ?? const [],
          onChanged: (value) =>
              setState(() => _singleRelationValues[field.name] = value),
        );
      case AdminFieldType.relationMultiple:
        return AdminMultiRelationField(
          field: field,
          selected: _multiRelationValues[field.name] ?? <String>{},
          records: widget.relationData[field.relationCollection] ?? const [],
          onToggle: (id, isSelected) {
            setState(() {
              final nextValues = _multiRelationValues[field.name] ?? <String>{};
              if (isSelected) {
                nextValues.add(id);
              } else {
                nextValues.remove(id);
              }
              _multiRelationValues[field.name] = nextValues;
            });
          },
        );
      case AdminFieldType.select:
        return AdminSelectField(
          field: field,
          value: _selectValues[field.name],
          onChanged: (value) => setState(() {
            _validationError = null;
            _selectValues[field.name] = value;
          }),
        );
      case AdminFieldType.file:
        return AdminFileField(
          field: field,
          fileController: _controllers[field.name]!,
          sourceController: _mediaSourceController,
          onSourceChanged: () => setState(() {}),
        );
      case AdminFieldType.multiline:
        return AdminMultilineField(
          field: field,
          controller: _controllers[field.name]!,
        );
      case AdminFieldType.text:
      case AdminFieldType.integer:
      case AdminFieldType.decimal:
      case AdminFieldType.dateTime:
        return AdminScalarField(
          field: field,
          controller: _controllers[field.name]!,
        );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final data = <String, dynamic>{};
    for (final field in widget.definition.fields) {
      switch (field.type) {
        case AdminFieldType.boolean:
          data[field.name] = _boolValues[field.name] ?? false;
          break;
        case AdminFieldType.relationSingle:
          data[field.name] = _singleRelationValues[field.name];
          break;
        case AdminFieldType.relationMultiple:
          data[field.name] =
              (_multiRelationValues[field.name] ?? <String>{}).toList()..sort();
          break;
        case AdminFieldType.select:
          data[field.name] = _selectValues[field.name];
          break;
        case AdminFieldType.file:
          break;
        case AdminFieldType.integer:
          final value = _controllers[field.name]!.text.trim();
          data[field.name] = value.isEmpty ? null : int.parse(value);
          break;
        case AdminFieldType.decimal:
          final value = _controllers[field.name]!.text.trim();
          data[field.name] = value.isEmpty
              ? null
              : double.parse(value.replaceAll(',', '.'));
          break;
        case AdminFieldType.text:
        case AdminFieldType.multiline:
        case AdminFieldType.dateTime:
          final value = _controllers[field.name]!.text.trim();
          data[field.name] = value.isEmpty ? null : value;
          break;
      }
    }

    final validationError = widget.definition.name == 'narrativeChapters'
        ? validateNarrativeChapterDraft(
            data: data,
            relationData: widget.relationData,
          )
        : null;
    if (validationError != null) {
      setState(() {
        _validationError = validationError;
      });
      return;
    }

    Navigator.of(context).pop(
      AdminRecordDraft(
        data: data,
        mediaSource: _mediaSourceController.text.trim().isEmpty
            ? null
            : _mediaSourceController.text.trim(),
      ),
    );
  }
}
