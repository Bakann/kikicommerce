import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../application/storefront/storefront_theme.dart';
import '../../providers/storefront_theme_providers.dart';
import 'cms_admin_auth.dart';

/// CMS-sidebar block that lets admins preview & publish a storefront theme.
///
/// Mounted at the top of [CmsSectionsSidebar]. Tapping a segment swaps the
/// previewed theme via [editingStorefrontThemeProvider] (visible to the admin
/// only). "Appliquer" persists the choice as `active_theme` in
/// `storefront_settings`; "Annuler" reverts the local override.
class CmsAppearanceBlock extends ConsumerWidget {
  final bool isDisabled;

  const CmsAppearanceBlock({super.key, this.isDisabled = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeStorefrontThemeProvider);
    final override = ref.watch(editingStorefrontThemeProvider);
    final activeTheme = activeAsync.value?.theme;
    final previewed = override ?? activeTheme ?? StorefrontTheme.fallback;
    final hasPendingChange =
        override != null && (activeTheme == null || override != activeTheme);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Apparence',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _ThemeSegmentedControl(
            value: previewed,
            onChanged: isDisabled
                ? null
                : (next) {
                    if (activeTheme != null && next == activeTheme) {
                      ref.read(editingStorefrontThemeProvider.notifier).state =
                          null;
                    } else {
                      ref.read(editingStorefrontThemeProvider.notifier).state =
                          next;
                    }
                  },
          ),
          const SizedBox(height: 10),
          Text(
            hasPendingChange
                ? 'Aperçu local — non publié'
                : 'Thème actif: ${activeTheme?.displayLabel ?? 'chargement...'}',
            style: TextStyle(
              fontSize: 11,
              color: hasPendingChange
                  ? const Color(0xFFA8892E)
                  : const Color(0xFF6F6F6F),
              fontWeight: hasPendingChange ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (hasPendingChange) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF333333),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: isDisabled
                        ? null
                        : () {
                            ref
                                    .read(
                                      editingStorefrontThemeProvider.notifier,
                                    )
                                    .state =
                                null;
                          },
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: isDisabled
                        ? null
                        : () {
                            final target = ref.read(
                              editingStorefrontThemeProvider,
                            );
                            if (target == null) return;
                            _apply(context, ref, target);
                          },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    StorefrontTheme target,
  ) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(storefrontSettingsRepositoryProvider)
          .saveActiveTheme(authToken: token, theme: target);
      ref.invalidate(activeStorefrontThemeProvider);
      final published = await ref.read(activeStorefrontThemeProvider.future);
      if (published.theme != target) {
        throw StateError(
          'Le thème publié relu est ${published.theme.displayLabel}, '
          'pas ${target.displayLabel}.',
        );
      }
      ref.read(editingStorefrontThemeProvider.notifier).state = null;
      messenger.showSnackBar(
        SnackBar(content: Text('Thème ${target.displayLabel} publié.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la publication : $error')),
      );
    }
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final StorefrontTheme value;
  final ValueChanged<StorefrontTheme>? onChanged;

  const _ThemeSegmentedControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final theme in StorefrontTheme.values)
            Expanded(
              child: _Segment(
                label: theme.displayLabel,
                isActive: theme == value,
                onTap: onChanged == null ? null : () => onChanged!(theme),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _Segment({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      elevation: isActive ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF111111)
                    : const Color(0xFF6F6F6F),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
