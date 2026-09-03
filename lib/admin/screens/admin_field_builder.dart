import 'package:flutter/material.dart';

import '../../core/utils/media_upload_guidance.dart';
import '../admin_collection_schema.dart';

class AdminBooleanField extends StatelessWidget {
  final AdminFieldDefinition field;
  final bool value;
  final ValueChanged<bool> onChanged;

  const AdminBooleanField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(field.label),
      onChanged: onChanged,
    );
  }
}

class AdminSingleRelationField extends StatelessWidget {
  final AdminFieldDefinition field;
  final String? value;
  final List<Map<String, dynamic>> records;
  final ValueChanged<String?> onChanged;

  const AdminSingleRelationField({
    super.key,
    required this.field,
    required this.value,
    required this.records,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final relatedDefinition =
        adminCollectionDefinitionsByName[field.relationCollection];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Aucun')),
        for (final record in records)
          DropdownMenuItem<String?>(
            value: record['id'] as String?,
            child: Text(
              relatedDefinition == null
                  ? (record['id'] as String? ?? '')
                  : adminRecordLabel(relatedDefinition, record),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class AdminMultiRelationField extends StatelessWidget {
  final AdminFieldDefinition field;
  final Set<String> selected;
  final List<Map<String, dynamic>> records;
  final void Function(String id, bool isSelected) onToggle;

  const AdminMultiRelationField({
    super.key,
    required this.field,
    required this.selected,
    required this.records,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final relatedDefinition =
        adminCollectionDefinitionsByName[field.relationCollection];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      child: records.isEmpty
          ? const Text('Aucune option disponible')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final record in records)
                  FilterChip(
                    label: Text(
                      relatedDefinition == null
                          ? (record['id'] as String? ?? '')
                          : adminRecordLabel(relatedDefinition, record),
                    ),
                    selected: selected.contains(record['id']),
                    onSelected: (value) =>
                        onToggle(record['id'] as String, value),
                  ),
              ],
            ),
    );
  }
}

class AdminSelectField extends StatelessWidget {
  final AdminFieldDefinition field;
  final String? value;
  final ValueChanged<String?> onChanged;

  const AdminSelectField({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = field.options ?? const <String>[];
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Aucun')),
        for (final option in options)
          DropdownMenuItem<String?>(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }
}

class AdminFileField extends StatelessWidget {
  final AdminFieldDefinition field;
  final TextEditingController fileController;
  final TextEditingController sourceController;
  final VoidCallback onSourceChanged;

  const AdminFileField({
    super.key,
    required this.field,
    required this.fileController,
    required this.sourceController,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: fileController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: sourceController,
          onChanged: (_) => onSourceChanged(),
          decoration: const InputDecoration(
            labelText: 'Source du fichier',
            hintText: 'asset://... ou https://...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        MediaUploadAdviceCard(
          isRemoteSource: sourceController.text.trim().isNotEmpty,
        ),
      ],
    );
  }
}

class AdminMultilineField extends StatelessWidget {
  final AdminFieldDefinition field;
  final TextEditingController controller;

  const AdminMultilineField({
    super.key,
    required this.field,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: field.label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class AdminScalarField extends StatelessWidget {
  final AdminFieldDefinition field;
  final TextEditingController controller;

  const AdminScalarField({
    super.key,
    required this.field,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isNumeric =
        field.type == AdminFieldType.integer ||
        field.type == AdminFieldType.decimal;
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.type == AdminFieldType.dateTime
            ? 'YYYY-MM-DD ou ISO datetime'
            : null,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => validateAdminScalarField(field, value),
    );
  }
}

String? validateAdminScalarField(AdminFieldDefinition field, String? rawValue) {
  final trimmed = rawValue?.trim() ?? '';
  if (field.required && trimmed.isEmpty) {
    return 'Champ requis';
  }
  if (trimmed.isEmpty) {
    return null;
  }
  if (field.type == AdminFieldType.integer && int.tryParse(trimmed) == null) {
    return 'Entier attendu';
  }
  if (field.type == AdminFieldType.decimal &&
      double.tryParse(trimmed.replaceAll(',', '.')) == null) {
    return 'Nombre attendu';
  }
  if (field.type == AdminFieldType.dateTime &&
      DateTime.tryParse(trimmed) == null) {
    return 'Date ou date-heure ISO attendue';
  }
  return null;
}

class MediaUploadAdviceCard extends StatelessWidget {
  final bool isRemoteSource;

  const MediaUploadAdviceCard({super.key, required this.isRemoteSource});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4DB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5C97A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conseil image',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Limite PocketBase: ${formatBytesForHumans(mediaUploadPocketBaseMaxBytes)}. '
            'Cible recommandée: moins de ${formatBytesForHumans(mediaUploadRecommendedMaxBytes)}, '
            'en WebP ou JPEG, avec un côté long autour de ${mediaUploadRecommendedLongEdge}px.',
            style: textTheme.bodySmall,
          ),
          if (isRemoteSource) ...[
            const SizedBox(height: 6),
            Text(
              'Une source distante sera importée telle quelle. Si elle est lourde, optimise-la avant l’upload.',
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
