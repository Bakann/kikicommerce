import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../application/cms/cms_models.dart';

String? cmsTrimToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String cmsStringValue(Object? raw) => raw is String ? raw : '';

Map<String, dynamic>? cmsCtaMap({required String label, required String href}) {
  final normalizedLabel = cmsTrimToNull(label);
  final normalizedHref = cmsTrimToNull(href);
  if (normalizedLabel == null && normalizedHref == null) return null;
  return <String, dynamic>{'label': ?normalizedLabel, 'href': ?normalizedHref};
}

Map<String, dynamic>? cmsMediaMap(CmsMediaRef? ref) {
  if (ref == null) return null;
  return <String, dynamic>{
    'recordId': ref.recordId,
    'collectionId': ref.collectionId,
    'filename': ref.filename,
    'alt': ?ref.alt,
  };
}

String cmsNormalizeOption(
  Object? raw,
  List<String> allowed,
  String fallback, {
  bool caseSensitive = false,
}) {
  final value = raw is String ? raw.trim() : '';
  if (value.isEmpty) return fallback;
  for (final option in allowed) {
    if (caseSensitive) {
      if (option == value) return option;
    } else if (option.toLowerCase() == value.toLowerCase()) {
      return option;
    }
  }
  return fallback;
}

int cmsNormalizeColumns(Object? raw, int fallback) {
  final value = raw is num ? raw.toInt() : fallback;
  if (value < 1) return 1;
  if (value > 6) return 6;
  return value;
}

List<dynamic> cmsListValue(Object? raw) {
  if (raw is! List) return <dynamic>[];
  return List<dynamic>.from(raw);
}

String cmsPrettyJson(Object? data) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(data);
}

class CmsFormSectionHeader extends StatelessWidget {
  final String label;

  const CmsFormSectionHeader({super.key, required this.label});

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

class CmsJsonArrayField extends StatefulWidget {
  final String label;
  final List<dynamic> initialValue;
  final ValueChanged<List<dynamic>> onChanged;
  final bool enabled;
  final String? helperText;

  const CmsJsonArrayField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
    this.helperText,
  });

  @override
  State<CmsJsonArrayField> createState() => _CmsJsonArrayFieldState();
}

class _CmsJsonArrayFieldState extends State<CmsJsonArrayField> {
  late TextEditingController _controller;
  late String _lastInitialJson;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _lastInitialJson = cmsPrettyJson(widget.initialValue);
    _controller = TextEditingController(text: _lastInitialJson);
    _controller.addListener(_emitIfValid);
  }

  @override
  void didUpdateWidget(covariant CmsJsonArrayField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextInitialJson = cmsPrettyJson(widget.initialValue);
    if (nextInitialJson != _lastInitialJson &&
        _controller.text == _lastInitialJson) {
      _lastInitialJson = nextInitialJson;
      _controller.text = nextInitialJson;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_emitIfValid);
    _controller.dispose();
    super.dispose();
  }

  void _emitIfValid() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! List) {
        if (_errorText != 'Le JSON doit être un tableau.') {
          setState(() => _errorText = 'Le JSON doit être un tableau.');
        }
        return;
      }
      _lastInitialJson = _controller.text;
      if (_errorText != null) {
        setState(() => _errorText = null);
      }
      widget.onChanged(List<dynamic>.from(decoded));
    } catch (error) {
      final message = 'JSON invalide : $error';
      if (_errorText != message) {
        setState(() => _errorText = message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      minLines: 5,
      maxLines: 10,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.4,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        errorText: _errorText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}
