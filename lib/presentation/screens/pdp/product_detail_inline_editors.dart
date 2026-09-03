import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants.dart';
import '../product_detail_layout_spec.dart';

const kProductNameEditorSemanticsLabel = 'Modifier le nom du produit';
const kProductNameEditorSemanticsIdentifier = 'product-name-editor-trigger';
const kProductSummaryEditorSemanticsLabel = 'Modifier le résumé du produit';
const kProductSummaryEditorSemanticsIdentifier =
    'product-summary-editor-trigger';
const kProductNameEditorInputKey = 'product-name-editor-input';

class EditableProductName extends StatefulWidget {
  final String name;
  final bool isEditMode;
  final ProductDetailLayoutSpec layout;
  final Future<bool> Function(String value)? onSave;

  const EditableProductName({
    super.key,
    required this.name,
    required this.isEditMode,
    required this.layout,
    this.onSave,
  });

  @override
  State<EditableProductName> createState() => _EditableProductNameState();
}

class _EditableProductNameState extends State<EditableProductName> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant EditableProductName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && !_isEditing) {
      _controller.text = widget.name;
    }
    if (!widget.isEditMode && _isEditing) {
      _cancel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  TextStyle get _titleStyle => TextStyle(
    fontSize: widget.layout.titleFontSize,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF2F2F2C),
    height: widget.layout.isMobile ? 0.98 : 1.08,
    letterSpacing: 0,
    fontFamily: widget.layout.isMobile
        ? GoogleFonts.cormorantGaramond().fontFamily
        : GoogleFonts.notoSerif().fontFamily,
  );

  void _startEditing() {
    if (!widget.isEditMode || widget.onSave == null) return;
    setState(() {
      _isEditing = true;
      _errorText = null;
      _controller
        ..text = widget.name
        ..selection = TextSelection.collapsed(offset: widget.name.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _cancel() {
    _focusNode.unfocus();
    setState(() {
      _isEditing = false;
      _isSaving = false;
      _errorText = null;
      _controller.text = widget.name;
    });
  }

  Future<void> _submit() async {
    final nextValue = _controller.text.trim();
    if (nextValue.isEmpty) {
      setState(() {
        _errorText = 'Le nom du produit est requis.';
      });
      return;
    }
    if (nextValue == widget.name.trim()) {
      _cancel();
      return;
    }

    final onSave = widget.onSave;
    if (onSave == null) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final success = await onSave(nextValue);
    if (!mounted) return;

    if (success) {
      _focusNode.unfocus();
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      if (!widget.isEditMode) {
        return Text(widget.name, style: _titleStyle);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name, style: _titleStyle),
          const SizedBox(height: 10),
          EditActionButton(
            label: 'Modifier le titre',
            semanticsLabel: kProductNameEditorSemanticsLabel,
            semanticsIdentifier: kProductNameEditorSemanticsIdentifier,
            onPressed: _startEditing,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey(kProductNameEditorInputKey),
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          style: _titleStyle,
          decoration: InputDecoration(
            errorText: _errorText,
            hintText: 'Nom du produit',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE8E0D5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE8E0D5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kNavyBlue, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _isSaving ? null : _cancel,
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ],
    );
  }
}

class EditActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final String semanticsLabel;
  final String semanticsIdentifier;

  const EditActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.semanticsLabel,
    required this.semanticsIdentifier,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: semanticsLabel,
      identifier: semanticsIdentifier,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class ProductTextEditorPage extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final Future<bool> Function(String value) onSave;

  const ProductTextEditorPage({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.onSave,
  });

  @override
  State<ProductTextEditorPage> createState() => _ProductTextEditorPageState();
}

class _ProductTextEditorPageState extends State<ProductTextEditorPage> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  bool get _hasChanges => _controller.text.trim() != widget.initialValue.trim();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    setState(() {});
  }

  Future<void> _save() async {
    if (_isSaving || !_hasChanges) return;

    setState(() {
      _isSaving = true;
    });

    final success = await widget.onSave(_controller.text);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 92,
        leading: TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Annuler'),
        ),
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: (_isSaving || !_hasChanges) ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.hintText,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: null,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: 'Résumé produit',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE8E0D5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE8E0D5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: kNavyBlue, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_controller.text.trim().length} caractères',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
