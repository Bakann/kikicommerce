import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../l10n/l10n_extension.dart';
import '../providers/search_providers.dart';
import '../widgets/storefront_layout.dart';

/// Search entry screen shown at `/search` before a query is submitted.
///
/// A focused input plus live, debounced product-name suggestions. Picking a
/// suggestion — or submitting the field — navigates to `/search?q=…`, which
/// renders the real results grid. Mirrors the luxe search flow (submit → real
/// results) and adds the autocomplete list on top.
class SearchEntryPage extends ConsumerStatefulWidget {
  const SearchEntryPage({super.key});

  @override
  ConsumerState<SearchEntryPage> createState() => _SearchEntryPageState();
}

class _SearchEntryPageState extends ConsumerState<SearchEntryPage> {
  // Wait for a typing pause before querying so we don't fire per keystroke.
  static const _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  String _debouncedQuery = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
    });
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    context.go(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.searchUrl(query: trimmed),
        locale: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePadding = StorefrontLayout.outerPaddingFor(
      screenWidth,
      maxWidth: StorefrontLayout.productListMaxWidth,
    );

    // Below 2 chars the provider returns nothing; skip the watch entirely.
    final suggestions = _debouncedQuery.length < 2
        ? const <String>[]
        : (ref.watch(productNameSuggestionsProvider(_debouncedQuery)).value ??
              const <String>[]);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchField(
              controller: _controller,
              focusNode: _focusNode,
              hintText: context.l10n.navSearchHint,
              onChanged: _onChanged,
              onSubmit: _submit,
            ),
            const SizedBox(height: 22),
            if (suggestions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.searchSuggestionsTitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF70727A),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final name = suggestions[index];
                    return _SuggestionTile(
                      label: name,
                      query: _debouncedQuery,
                      onTap: () => _submit(name),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 24, color: Color(0xFF111111)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('search-entry-field'),
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmit,
              cursorColor: const Color(0xFF111111),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF70727A),
                  fontSize: 17,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF111111),
                fontSize: 17,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox(width: 8);
              return IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  focusNode.requestFocus();
                },
                icon: const Icon(
                  Icons.close,
                  size: 22,
                  color: Color(0xFF70727A),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String label;
  final String query;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.label,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: _buildEmphasizedLabel(),
      ),
    );
  }

  // Bold + dark the matched substring, grey the rest (cf. the reference UI).
  Widget _buildEmphasizedLabel() {
    const matched = TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF111111),
    );
    const rest = TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.w400,
      color: Color(0xFF70727A),
    );

    final lowerLabel = label.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerQuery.isEmpty ? -1 : lowerLabel.indexOf(lowerQuery);
    if (matchIndex < 0) {
      return Text(label, style: matched);
    }

    final before = label.substring(0, matchIndex);
    final mid = label.substring(matchIndex, matchIndex + query.length);
    final after = label.substring(matchIndex + query.length);
    return Text.rich(
      TextSpan(
        children: [
          if (before.isNotEmpty) TextSpan(text: before, style: rest),
          TextSpan(text: mid, style: matched),
          if (after.isNotEmpty) TextSpan(text: after, style: rest),
        ],
      ),
    );
  }
}
