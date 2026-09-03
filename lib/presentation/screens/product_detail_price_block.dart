import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/catalog/save_product_price.dart';
import '../../core/constants.dart';
import '../../core/utils/price_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';
import 'product_detail_layout_spec.dart';

const kProductPriceEditorSemanticsLabel = 'Modifier le prix du produit';
const kProductPriceEditorSemanticsIdentifier = 'product-price-editor-trigger';
const kProductPriceEditorInputKey = 'product-price-editor-input';

String formatEditableProductPriceInput(double price) =>
    normalizeProductPrice(price).toStringAsFixed(2).replaceAll('.', ',');

double? parseEditableProductPriceInput(String rawValue) {
  final sanitized = rawValue
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(',', '.');
  if (sanitized.isEmpty) {
    return null;
  }
  final parsed = double.tryParse(sanitized);
  if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
    return null;
  }
  return normalizeProductPrice(parsed);
}

class ProductDetailPriceBlock extends StatefulWidget {
  final CatalogPrice? defaultPrice;
  final double? originalPrice;
  final int? discount;
  final String symbol;
  final ProductDetailLayoutSpec layout;
  final bool isEditMode;
  final bool showStandaloneValue;
  final Future<bool> Function(double value)? onSave;

  const ProductDetailPriceBlock({
    super.key,
    required this.defaultPrice,
    required this.originalPrice,
    required this.discount,
    required this.symbol,
    required this.layout,
    required this.isEditMode,
    required this.showStandaloneValue,
    this.onSave,
  });

  @override
  State<ProductDetailPriceBlock> createState() =>
      _ProductDetailPriceBlockState();
}

class _ProductDetailPriceBlockState extends State<ProductDetailPriceBlock> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorText;

  CatalogPrice? get _priceRow => widget.defaultPrice;
  bool get _canEdit => widget.isEditMode && widget.onSave != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _priceRow == null
          ? ''
          : formatEditableProductPriceInput(_priceRow!.price),
    );
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ProductDetailPriceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPrice = oldWidget.defaultPrice?.price;
    final nextPrice = widget.defaultPrice?.price;
    if (oldPrice != nextPrice && !_isEditing) {
      _controller.text = nextPrice == null
          ? ''
          : formatEditableProductPriceInput(nextPrice);
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

  void _startEditing() {
    if (!_canEdit) {
      return;
    }
    final priceRow = _priceRow;
    setState(() {
      _isEditing = true;
      _errorText = null;
      _controller
        ..text = priceRow == null
            ? ''
            : formatEditableProductPriceInput(priceRow.price)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _cancel() {
    final priceRow = _priceRow;
    _focusNode.unfocus();
    setState(() {
      _isEditing = false;
      _isSaving = false;
      _errorText = null;
      _controller.text = priceRow == null
          ? ''
          : formatEditableProductPriceInput(priceRow.price);
    });
  }

  Future<void> _submit() async {
    final priceRow = _priceRow;
    final onSave = widget.onSave;
    if (onSave == null) {
      return;
    }

    final parsed = parseEditableProductPriceInput(_controller.text);
    if (parsed == null) {
      setState(() {
        _errorText = 'Saisissez un prix valide, par exemple 49,90.';
      });
      return;
    }

    if (priceRow != null && isSameProductPrice(priceRow.price, parsed)) {
      _cancel();
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final success = await onSave(parsed);
    if (!mounted) {
      return;
    }

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
    if (!widget.showStandaloneValue && !widget.isEditMode && !_isEditing) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isEditMode && !_isEditing) ...[
          Text(
            _priceRow == null ? 'Prix PDP à créer' : 'Prix PDP',
            style: TextStyle(
              fontSize: widget.layout.referenceFontSize + 1,
              fontWeight: FontWeight.w600,
              color: productDetailMutedTextColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (_isEditing)
          _buildEditor()
        else if (widget.showStandaloneValue)
          _buildDisplay(),
        if (widget.isEditMode && !_isEditing) ...[
          const SizedBox(height: 12),
          if (_canEdit)
            _PriceEditActionButton(
              onPressed: _startEditing,
              label: _priceRow == null ? 'Ajouter un prix' : 'Modifier le prix',
            )
          else
            _buildUnavailableHint(),
        ],
      ],
    );
  }

  Widget _buildDisplay() {
    final defaultPrice = widget.defaultPrice;
    final originalPrice = widget.originalPrice;
    final discount = widget.discount;

    if (defaultPrice == null) {
      return Text(
        context.l10n.pdpPriceUnavailable,
        style: TextStyle(
          fontSize: widget.layout.priceFontSize,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF6D6C68),
          height: 1.1,
        ),
      );
    }

    if (originalPrice != null || discount != null) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            formatPrice(defaultPrice.price, widget.symbol),
            style: TextStyle(
              fontSize: widget.layout.priceFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
              height: 1.1,
            ),
          ),
          if (originalPrice != null)
            Text(
              formatPrice(originalPrice, widget.symbol),
              style: TextStyle(
                fontSize: widget.layout.subtitleFontSize,
                color: Colors.grey.shade500,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          if (discount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '-$discount%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Text(
      formatPrice(defaultPrice.price, widget.symbol),
      style: TextStyle(
        fontSize: widget.layout.priceFontSize,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1E1E1C),
        height: 1.1,
      ),
    );
  }

  Widget _buildEditor() {
    final priceRow = _priceRow;
    final currencyCode = priceRow?.currencyCode?.trim();
    final isCreating = priceRow == null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.layout.isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6D7B9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isCreating
                      ? 'Ajouter le prix affiché'
                      : 'Modifier le prix affiché',
                  style: TextStyle(
                    fontSize: widget.layout.isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2F2F2C),
                  ),
                ),
              ),
              if (currencyCode != null && currencyCode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6D7B9)),
                  ),
                  child: Text(
                    currencyCode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6D6C68),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCreating
                ? 'Aucune ligne de prix active n’existe encore. Cette action en créera une pour la PDP.'
                : 'Le changement met à jour la ligne de prix active utilisée sur la PDP.',
            style: TextStyle(
              fontSize: widget.layout.isMobile ? 12.5 : 13,
              color: const Color(0xFF6B6A65),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey(kProductPriceEditorInputKey),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
            ],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              errorText: _errorText,
              labelText: 'Prix',
              suffixText: widget.symbol,
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
          const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildUnavailableHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Aucune ligne de prix active n’est disponible pour cette PDP.',
        style: TextStyle(
          fontSize: widget.layout.isMobile ? 12.5 : 13,
          color: const Color(0xFF6B6A65),
          height: 1.4,
        ),
      ),
    );
  }
}

class _PriceEditActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _PriceEditActionButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: kProductPriceEditorSemanticsLabel,
      identifier: kProductPriceEditorSemanticsIdentifier,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.sell_outlined, size: 18),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
