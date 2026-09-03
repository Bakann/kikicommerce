import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_providers.dart';
import '../../application/storefront/storefront_brand_settings.dart';
import 'cms/cms_admin_auth.dart';

class StorefrontBrandEditorDialog extends ConsumerStatefulWidget {
  final StorefrontBrandSettings initialSettings;

  const StorefrontBrandEditorDialog({super.key, required this.initialSettings});

  static Future<void> show(
    BuildContext context, {
    required StorefrontBrandSettings initialSettings,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          StorefrontBrandEditorDialog(initialSettings: initialSettings),
    );
  }

  @override
  ConsumerState<StorefrontBrandEditorDialog> createState() =>
      _StorefrontBrandEditorDialogState();
}

class _StorefrontBrandEditorDialogState
    extends ConsumerState<StorefrontBrandEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _hrefController;
  late bool _replaceMobileLogoWithThemeSwitcher;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialSettings.title,
    );
    _hrefController = TextEditingController(text: widget.initialSettings.href);
    _replaceMobileLogoWithThemeSwitcher =
        widget.initialSettings.replaceMobileLogoWithThemeSwitcher;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hrefController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final token = await ensureAdminToken(context, ref);
    if (token == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final next = StorefrontBrandSettings(
        id: widget.initialSettings.id,
        title: _titleController.text.trim(),
        href: StorefrontBrandSettings.normalizedHref(_hrefController.text),
        replaceMobileLogoWithThemeSwitcher: _replaceMobileLogoWithThemeSwitcher,
      );
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: storefrontSettingsCollection,
        recordId: next.id,
        data: next.toPayload(),
      );
      ref.invalidate(storefrontBrandSettingsProvider);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = screenWidth < 560 ? screenWidth - 32 : 480.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Identité de la boutique',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Nom affiché dans la navbar',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (value) {
                    final title = value?.trim() ?? '';
                    if (title.isEmpty) {
                      return 'Le titre est requis.';
                    }
                    if (title.length > 60) {
                      return 'Le titre doit faire 60 caractères maximum.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _hrefController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Lien du titre',
                    hintText: '/',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final href = value?.trim() ?? '';
                    if (href.isEmpty) return null;
                    if (href.length > 200) {
                      return 'Le lien doit faire 200 caractères maximum.';
                    }
                    final isExternal =
                        href.startsWith('http://') ||
                        href.startsWith('https://');
                    if (!isExternal && !href.startsWith('/')) {
                      return 'Utilisez une URL interne commençant par / ou une URL http(s).';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Remplacer le logo par le switch Sport/Luxe sur mobile',
                  ),
                  value: _replaceMobileLogoWithThemeSwitcher,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(
                            () => _replaceMobileLogoWithThemeSwitcher = value,
                          );
                        },
                ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: _titleController,
                  builder: (context, _) {
                    final title = _titleController.text.trim().isEmpty
                        ? defaultStorefrontBrandTitle
                        : _titleController.text.trim();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2B2B2B),
                          letterSpacing: 0,
                          height: 1,
                        ),
                      ),
                    );
                  },
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
