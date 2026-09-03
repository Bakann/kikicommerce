import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/storefront/storefront_brand_settings.dart';
import '../../application/storefront/storefront_navigation_settings.dart';
import 'cms/cms_admin_auth.dart';

class StorefrontNavigationEditorDialog extends ConsumerStatefulWidget {
  final StorefrontNavigationSettings initialSettings;

  const StorefrontNavigationEditorDialog({
    super.key,
    required this.initialSettings,
  });

  static Future<void> show(
    BuildContext context, {
    required StorefrontNavigationSettings initialSettings,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          StorefrontNavigationEditorDialog(initialSettings: initialSettings),
    );
  }

  @override
  ConsumerState<StorefrontNavigationEditorDialog> createState() =>
      _StorefrontNavigationEditorDialogState();
}

class _StorefrontNavigationEditorDialogState
    extends ConsumerState<StorefrontNavigationEditorDialog> {
  late MobileMenuStyle _selectedStyle;
  late CategorySplitDisplayMode _selectedSplitMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.initialSettings.mobileMenuStyle;
    _selectedSplitMode = widget.initialSettings.categorySplitDisplayMode;
  }

  Future<void> _save() async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final next = widget.initialSettings.copyWith(
        mobileMenuStyle: _selectedStyle,
        categorySplitDisplayMode: _selectedSplitMode,
      );
      final recordId = next.id ?? await _findExistingNavigationRecordId(token);

      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: storefrontSettingsCollection,
        recordId: recordId,
        data: next.toPayload(),
      );
      ref.invalidate(storefrontNavigationSettingsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’enregistrer : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _findExistingNavigationRecordId(String token) async {
    final records = await ref
        .read(adminBackofficeRepositoryProvider)
        .listRecords(
          baseUrl: ref.read(apiBaseUrlProvider),
          authToken: token,
          collection: storefrontSettingsCollection,
          perPage: 1,
          filter: 'key = "$storefrontNavigationSettingsKey"',
        );
    if (records.isEmpty) {
      return null;
    }
    return (records.first['id'] as String?)?.trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 640 ? screenWidth - 32 : 560.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.sizeOf(context).height - 32,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Navigation mobile',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Style du menu mobile',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _StyleCard(
                  title: 'Drawer classique',
                  description: 'Panneau latéral actuel.',
                  selected: _selectedStyle == MobileMenuStyle.drawer,
                  onTap: _isSaving
                      ? null
                      : () => setState(() {
                          _selectedStyle = MobileMenuStyle.drawer;
                        }),
                ),
                const SizedBox(height: 10),
                _StyleCard(
                  title: 'Plein écran premium',
                  description:
                      'Page de menu plein écran révélée depuis le haut.',
                  selected: _selectedStyle == MobileMenuStyle.fullscreenReveal,
                  onTap: _isSaving
                      ? null
                      : () => setState(() {
                          _selectedStyle = MobileMenuStyle.fullscreenReveal;
                        }),
                ),
                const SizedBox(height: 18),
                _PreviewCard(style: _selectedStyle),
                const SizedBox(height: 26),
                Text(
                  'Menu catégories (sport)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _StyleCard(
                  title: 'Onglets',
                  description:
                      'Barre d’onglets de segments (Homme / Femme / Enfant).',
                  selected: _selectedSplitMode == CategorySplitDisplayMode.tabs,
                  onTap: _isSaving
                      ? null
                      : () => setState(() {
                          _selectedSplitMode = CategorySplitDisplayMode.tabs;
                        }),
                ),
                const SizedBox(height: 10),
                _StyleCard(
                  title: 'Expansible',
                  description:
                      'En-tête repliable : segments + sous-catégories du segment.',
                  selected:
                      _selectedSplitMode == CategorySplitDisplayMode.expansible,
                  onTap: _isSaving
                      ? null
                      : () => setState(() {
                          _selectedSplitMode =
                              CategorySplitDisplayMode.expansible;
                        }),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  const _StyleCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? theme.colorScheme.primary
        : const Color(0xFFE1E1E1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? theme.colorScheme.primary : Colors.black45,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final MobileMenuStyle style;

  const _PreviewCard({required this.style});

  @override
  Widget build(BuildContext context) {
    final isFullscreen = style == MobileMenuStyle.fullscreenReveal;

    return Container(
      height: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE4E1DD)),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFFAF9F7),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE6E3DF)),
              ),
            ),
          ),
          Positioned(
            top: isFullscreen ? 20 : 34,
            left: isFullscreen ? 0 : 0,
            right: isFullscreen ? 0 : null,
            bottom: 0,
            width: isFullscreen ? null : 92,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE6E3DF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _PreviewLine(widthFactor: 0.72),
                  SizedBox(height: 8),
                  _PreviewLine(widthFactor: 0.92),
                  SizedBox(height: 8),
                  _PreviewLine(widthFactor: 0.58),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final double widthFactor;

  const _PreviewLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B).withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(3.5),
        ),
      ),
    );
  }
}
