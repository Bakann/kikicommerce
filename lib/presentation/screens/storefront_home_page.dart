import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/catalog_routes.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/storefront/storefront_chrome_profile.dart';
import '../../application/storefront/storefront_sport_segment.dart';
import '../../core/utils/slug_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../providers/catalog_invalidator_provider.dart';
import '../providers/category_providers.dart';
import '../providers/content_locale_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/storefront_theme_providers.dart';
import '../l10n/l10n_extension.dart';
import '../widgets/category_plp_hero.dart';
import '../widgets/cms/cms_admin_auth.dart';
import '../widgets/navigation/sport_home_icon_loading_publisher.dart';
import 'cms_product_list_page.dart';

class StorefrontHomePage extends ConsumerWidget {
  final String? categorySlug;
  final StorefrontSportSegment? sportSegment;

  const StorefrontHomePage({super.key, this.categorySlug, this.sportSegment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(editModeProvider);
    final categoryAsync = categorySlug == null
        ? ref.watch(defaultCategoryProvider)
        : ref.watch(categoryBySlugProvider(categorySlug!));
    final usesSportHomeIconLoading =
        sportSegment != null || _usesSportBottomNav(ref);

    final body = categoryAsync.when(
      // Mount the hero placeholder on the destination's FIRST frame (before the
      // category resolves) so the inbound tile→PLP Hero flight has a target on
      // a cold visit. Without this the first navigation falls back to a plain
      // page transition; the flight only worked once the category was cached.
      loading: () => _CategoryResolveLoading(slugKey: categorySlug),
      // The PocketBase/backoffice guidance is admin-only: public visitors get a
      // sober message with no admin CTA; editors get the technical remediation.
      error: (error, _) => isEditMode
          ? _StorefrontEmptyState(
              title: context.l10n.homeCatalogLoadErrorTitle,
              message: context.l10n.homeCatalogLoadErrorMessage,
              actionLabel: context.l10n.homeOpenBackoffice,
            )
          : _StorefrontEmptyState(
              title: context.l10n.homeCatalogUnavailableTitle,
              message: context.l10n.homeCatalogUnavailableMessage,
            ),
      data: (category) {
        if (category == null) {
          if (isEditMode && categorySlug != null) {
            return _MissingCategoryEditState(
              categorySlug: categorySlug!,
              sportSegment: sportSegment,
            );
          }
          if (isEditMode) {
            return _StorefrontEmptyState(
              title: context.l10n.homeNoActiveCategoriesTitle,
              message: context.l10n.homeNoActiveCategoriesMessage,
              actionLabel: context.l10n.homeImportData,
            );
          }
          // Public: distinguish a genuinely empty catalogue (no requested
          // category) from an unknown/inactive category or URL — without
          // leaking any technical/admin detail.
          if (categorySlug == null) {
            return _StorefrontEmptyState(
              title: context.l10n.homeEmptyPublicTitle,
              message: context.l10n.homeEmptyPublicMessage,
            );
          }
          return _StorefrontEmptyState(
            title: context.l10n.homeCategoryUnavailableTitle,
            message: context.l10n.homeCategoryUnavailableMessage,
          );
        }
        return CmsProductListPage(
          category: category,
          heroSlugKey: categorySlug,
        );
      },
    );

    return SportHomeIconLoadingPublisher(
      isLoading:
          usesSportHomeIconLoading &&
          categorySlug != null &&
          categoryAsync.isLoading &&
          !categoryAsync.hasValue,
      child: body,
    );
  }

  bool _usesSportBottomNav(WidgetRef ref) {
    final theme = ref.watch(effectiveStorefrontThemeAsyncProvider).value;
    return theme != null &&
        StorefrontChromeProfile.forTheme(theme).showFloatingBottomNav;
  }
}

/// Loading placeholder shown while a category PLP resolves. When reached from a
/// tapped tile (a pending hint keyed by [slugKey]), it renders the 1:1 hero with
/// the carried tile image at the top — present on the first frame so the Hero
/// flight pairs — with a spinner below for the still-loading product grid.
/// Falls back to a bare spinner when there is no slug or no pending hint
/// ([CategoryPlpHero] collapses to nothing in that case).
class _CategoryResolveLoading extends StatelessWidget {
  final String? slugKey;

  const _CategoryResolveLoading({required this.slugKey});

  @override
  Widget build(BuildContext context) {
    if (slugKey == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        CategoryPlpHero(slugKey: slugKey!, categoryId: null),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

class _MissingCategoryEditState extends ConsumerWidget {
  final String categorySlug;
  final StorefrontSportSegment? sportSegment;

  const _MissingCategoryEditState({
    required this.categorySlug,
    required this.sportSegment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(contentLocaleProvider);
    final pathLabel = CatalogRoutes.localizedLocation(
      sportSegment == null
          ? CatalogRoutes.categoryBySlug(categorySlug)
          : CatalogRoutes.sportCategoryLocation(
              segment: sportSegment!,
              categorySlug: categorySlug,
            ),
      locale: locale,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_box_outlined, size: 72),
              const SizedBox(height: 20),
              Text(
                'Cette tuile pointe vers une catégorie inexistante',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$pathLabel ne correspond à aucune catégorie active.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const _ContextChip(label: 'Sport'),
                  if (sportSegment != null)
                    _ContextChip(label: sportSegment!.displayLabel),
                  _ContextChip(label: categorySlug),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer la catégorie'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(CatalogRoutes.admin),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Ouvrir le backoffice'),
                  ),
                  if (sportSegment != null)
                    TextButton.icon(
                      onPressed: () => context.go(
                        CatalogRoutes.localizedLocation(
                          CatalogRoutes.sportSegmentLocation(sportSegment!),
                          locale: ref.read(contentLocaleProvider),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: Text('Retour à ${sportSegment!.displayLabel}'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateMissingCategoryDialog(
        categorySlug: categorySlug,
        sportSegment: sportSegment,
      ),
    );
    if (created != true || !context.mounted) {
      return;
    }

    final target = sportSegment == null
        ? CatalogRoutes.categoryBySlug(categorySlug)
        : CatalogRoutes.sportCategoryLocation(
            segment: sportSegment!,
            categorySlug: categorySlug,
          );
    context.go(
      CatalogRoutes.localizedLocation(
        target,
        locale: ref.read(contentLocaleProvider),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;

  const _ContextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
      ),
    );
  }
}

class _DropdownLabel extends StatelessWidget {
  final String text;
  final double width;

  const _DropdownLabel({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _CreateMissingCategoryDialog extends ConsumerStatefulWidget {
  final String categorySlug;
  final StorefrontSportSegment? sportSegment;

  const _CreateMissingCategoryDialog({
    required this.categorySlug,
    required this.sportSegment,
  });

  @override
  ConsumerState<_CreateMissingCategoryDialog> createState() =>
      _CreateMissingCategoryDialogState();
}

class _CreateMissingCategoryDialogState
    extends ConsumerState<_CreateMissingCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _positionController;
  bool _isActive = true;
  bool _isHidden = false;
  bool _saving = false;
  String? _parentId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final name = _titleFromSlug(widget.categorySlug);
    _nameController = TextEditingController(text: name);
    _slugController = TextEditingController(text: slugify(widget.categorySlug));
    _codeController = TextEditingController(text: _defaultCode());
    _descriptionController = TextEditingController();
    _positionController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(drawerCategoriesProvider);
    final isBusy = _saving;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Créer la catégorie',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Les champs sont préremplis depuis la tuile cliquée.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Nom'),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _slugController,
                          decoration: const InputDecoration(labelText: 'Slug'),
                          validator: (value) {
                            if (_required(value) != null) {
                              return _required(value);
                            }
                            final normalized = slugify(value);
                            if (normalized != value?.trim()) {
                              return 'Utilisez un slug normalisé, ex: $normalized';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(labelText: 'Code'),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        categoriesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text(
                            'Parents indisponibles: $error',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          data: (categories) {
                            final parentCandidates = categories
                                .where(
                                  (category) =>
                                      category.id.isNotEmpty &&
                                      category.slug !=
                                          _slugController.text.trim(),
                                )
                                .toList();
                            _parentId ??= _preferredParent(parentCandidates);
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final itemWidth = (constraints.maxWidth - 56)
                                    .clamp(80.0, constraints.maxWidth)
                                    .toDouble();
                                return DropdownButtonFormField<String?>(
                                  initialValue: _parentId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Parent',
                                  ),
                                  selectedItemBuilder: (context) => [
                                    _DropdownLabel(
                                      text: 'Aucun parent',
                                      width: itemWidth,
                                    ),
                                    for (final category in parentCandidates)
                                      _DropdownLabel(
                                        text: _parentOptionLabel(category),
                                        width: itemWidth,
                                      ),
                                  ],
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: _DropdownLabel(
                                        text: 'Aucun parent',
                                        width: itemWidth,
                                      ),
                                    ),
                                    for (final category in parentCandidates)
                                      DropdownMenuItem<String?>(
                                        value: category.id,
                                        child: _DropdownLabel(
                                          text: _parentOptionLabel(category),
                                          width: itemWidth,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _parentId = value);
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _positionController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Position',
                          ),
                          validator: (value) {
                            final trimmed = value?.trim();
                            if (trimmed == null || trimmed.isEmpty) {
                              return null;
                            }
                            return int.tryParse(trimmed) == null
                                ? 'Entrez un nombre entier.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Actif'),
                          value: _isActive,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Masqué du drawer'),
                          value: _isHidden,
                          onChanged: (value) =>
                              setState(() => _isHidden = value),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    FilledButton.icon(
                      onPressed: isBusy ? null : _save,
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Créer et ouvrir'),
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

  String _defaultCode() {
    final parts = [
      'SPORT',
      if (widget.sportSegment != null) widget.sportSegment!.wireName,
      widget.categorySlug,
    ];
    return parts.join('-').toUpperCase().replaceAll('-', '_');
  }

  String? _preferredParent(List<CatalogCategory> categories) {
    final segment = widget.sportSegment?.wireName;
    if (segment == null) {
      return null;
    }
    for (final category in categories) {
      final slug = category.slug?.trim();
      if (slug == segment) {
        return category.id;
      }
    }
    return null;
  }

  String _parentOptionLabel(CatalogCategory category) {
    return '${category.name} (${category.slug ?? category.code})';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final slug = _slugController.text.trim();
    final description = _descriptionController.text.trim();
    final position = int.tryParse(_positionController.text.trim()) ?? 0;
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'slug': slug,
      'code': _codeController.text.trim(),
      'description': description,
      'position': position,
      'isActive': _isActive,
      'isHidden': _isHidden,
      if (_parentId != null) 'parent': _parentId,
    };

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        data: data,
      );
      if (!mounted) {
        return;
      }
      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, [
        const CategoryTreeInvalidation(),
        CategoryBySlugInvalidation(slug),
        const AllProductListsInvalidation(),
        const AllProductRoutesInvalidation(),
        const DrawerNavigationInvalidation(),
      ]);
      ref.invalidate(categoryBySlugProvider(slug));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Catégorie créée. Ajoutez des produits ou des sections pour construire la page.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Champ requis.' : null;
  }

  static String _titleFromSlug(String slug) {
    final words = slug.split('-').where((word) => word.trim().isNotEmpty).map((
      word,
    ) {
      if (word.isEmpty) {
        return word;
      }
      return '${word[0].toUpperCase()}${word.substring(1)}';
    });
    return words.join(' ');
  }
}

class _StorefrontEmptyState extends StatelessWidget {
  final String title;
  final String message;

  /// Admin-only call to action. When null (public visitors) no button renders.
  final String? actionLabel;

  const _StorefrontEmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 72),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go(CatalogRoutes.admin),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
