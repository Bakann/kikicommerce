import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cms/cms_models.dart';
import '../../application/cms/cms_page_repository.dart';
import '../../application/storefront/storefront_plp_profile.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../providers/cms_page_provider.dart';
import '../providers/cms_page_editor_controller.dart';
import '../providers/content_locale_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/storefront_shell_provider.dart';
import '../providers/storefront_theme_providers.dart';
import '../widgets/cms/cms_admin_auth.dart';
import '../widgets/cms/cms_edit_overlay.dart';
import '../widgets/cms/cms_section_renderer.dart';
import '../widgets/cms/cms_sections_sidebar.dart';
import '../widgets/cms/sections/hero_campaign_section.dart';
import '../widgets/storefront_layout.dart';
import 'product_list_page.dart';

class CmsProductListPage extends ConsumerStatefulWidget {
  final CatalogCategory category;

  /// Forwarded to the direct catalog [ProductListPage] (sport themes) so the
  /// category-tile → PLP Hero transition can mount its 1:1 hero. See
  /// [ProductListPage.heroSlugKey].
  final String? heroSlugKey;

  const CmsProductListPage({
    super.key,
    required this.category,
    this.heroSlugKey,
  });

  @override
  ConsumerState<CmsProductListPage> createState() => _CmsProductListPageState();
}

class _CmsProductListPageState extends ConsumerState<CmsProductListPage> {
  bool _isCmsSidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(editModeProvider);

    // Catalogue-first apparences (sport/Nike) render the direct catalogue
    // grid in public read instead of the CMS-composed PLP. This is a
    // render-path choice driven by the active apparence — the CMS PLP
    // records are untouched, and edit mode below still reaches the CMS PLP
    // so admins keep full access to manage it.
    if (!isEditMode) {
      final theme = ref.watch(effectiveStorefrontThemeAsyncProvider).value;
      if (theme != null &&
          StorefrontPlpProfile.forTheme(theme).prefersDirectCatalogGrid) {
        return ProductListPage(
          categoryId: widget.category.id,
          heroSlugKey: widget.heroSlugKey,
        );
      }
    }

    final locale = ref.watch(contentLocaleProvider);
    final plpAsync = ref.watch(
      cmsPlpProvider(
        CmsPlpRequest(categoryId: widget.category.id, locale: locale),
      ),
    );

    return plpAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ProductListPage(
        categoryId: widget.category.id,
        heroSlugKey: widget.heroSlugKey,
      ),
      data: (bundle) {
        if (bundle == null) {
          if (isEditMode) {
            return _CmsPlpBootstrapBody(
              category: widget.category,
              isSidebarExpanded: _isCmsSidebarExpanded,
              onSidebarExpandedChanged: (value) {
                setState(() => _isCmsSidebarExpanded = value);
              },
            );
          }
          return ProductListPage(
            categoryId: widget.category.id,
            heroSlugKey: widget.heroSlugKey,
          );
        }
        if (bundle.sections.isEmpty && !isEditMode) {
          return ProductListPage(
            categoryId: widget.category.id,
            heroSlugKey: widget.heroSlugKey,
          );
        }

        final visibleSections = isEditMode
            ? bundle.sections
            : bundle.sections
                  .where((s) => s.record.isActive && s is! CmsUnknownSection)
                  .toList(growable: false);

        final heroHeight = !isEditMode
            ? _heroHeightAtTop(context, visibleSections)
            : null;

        return _ImmersiveHeaderController(
          heroHeight: heroHeight,
          child: _CmsPlpBody(
            category: widget.category,
            bundle: bundle,
            isSidebarExpanded: _isCmsSidebarExpanded,
            onSidebarExpandedChanged: (value) {
              setState(() => _isCmsSidebarExpanded = value);
            },
          ),
        );
      },
    );
  }
}

class _CmsPlpBootstrapBody extends ConsumerWidget {
  final CatalogCategory category;
  final bool isSidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;

  const _CmsPlpBootstrapBody({
    required this.category,
    required this.isSidebarExpanded,
    required this.onSidebarExpandedChanged,
  });

  Future<void> _bootstrap(BuildContext context, WidgetRef ref) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cmsPageEditorControllerProvider.notifier)
          .bootstrapPlpForCategory(category);
      messenger.showSnackBar(const SnackBar(content: Text('PLP CMS créée.')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la création PLP : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(editModeProvider);
    final areEditControlsVisible = ref.watch(editControlsVisibleProvider);
    final isSaving = ref.watch(cmsPageEditorControllerProvider).isLoading;
    return Stack(
      fit: StackFit.expand,
      children: [
        ProductListPage(categoryId: category.id),
        if (isEditMode && isSidebarExpanded)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: _CmsPlpBootstrapSidebar(
              category: category,
              isSaving: isSaving,
              onCreate: () => _bootstrap(context, ref),
              onCollapse: () => onSidebarExpandedChanged(false),
            ),
          ),
        if (isEditMode && !isSidebarExpanded)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 84,
            left: 12,
            child: CmsSidebarToggleButton(
              isExpanded: false,
              onPressed: () => onSidebarExpandedChanged(true),
            ),
          ),
        if (areEditControlsVisible)
          Positioned(
            right: 16,
            bottom: 16,
            child: _EditModeFab(isEditMode: isEditMode),
          ),
      ],
    );
  }
}

class _CmsPlpBootstrapSidebar extends StatelessWidget {
  final CatalogCategory category;
  final bool isSaving;
  final VoidCallback onCreate;
  final VoidCallback onCollapse;

  const _CmsPlpBootstrapSidebar({
    required this.category,
    required this.isSaving,
    required this.onCreate,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 72;
    return Material(
      color: const Color(0xFFF7F6F2),
      elevation: 6,
      child: SizedBox(
        width: 336,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PLP CMS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CmsSidebarToggleButton(
                    isExpanded: true,
                    onPressed: onCollapse,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E0D8)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cette catégorie utilise encore la grille catalogue. '
                      'Créez une PLP CMS pour administrer les sections métier.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Color(0xFF5F5A50),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Primary action, kept above the (preview-only) section list so
              // it is always visible without scrolling.
              FilledButton.icon(
                onPressed: isSaving ? null : onCreate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 18),
                label: Text(isSaving ? 'Création…' : 'Créer la PLP CMS'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aucune page CMS n’est créée avant ce clic. Le hero affiché '
                'provient de la tuile et n’est pas encore éditable.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF7A756C)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sections à créer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF6F6A60),
                ),
              ),
              const SizedBox(height: 10),
              // Preview only — these sections do not exist until "Créer la PLP
              // CMS" is tapped, so they are dimmed and non-interactive.
              const Expanded(
                child: SingleChildScrollView(
                  child: Opacity(
                    opacity: 0.55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BootstrapSectionPreview(
                          label: 'Hero collection',
                          active: true,
                        ),
                        _BootstrapSectionPreview(
                          label: 'Grille produits enrichie',
                          active: true,
                        ),
                        _BootstrapSectionPreview(
                          label: 'Texte SEO',
                          active: false,
                        ),
                        _BootstrapSectionPreview(
                          label: 'Cartes services',
                          active: false,
                        ),
                        _BootstrapSectionPreview(
                          label: 'Liens découverte',
                          active: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapSectionPreview extends StatelessWidget {
  final String label;
  final bool active;

  const _BootstrapSectionPreview({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E0D8)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 16,
            color: active ? const Color(0xFF2D2D2A) : const Color(0xFF8A857B),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            active ? 'active' : 'masquée',
            style: TextStyle(
              fontSize: 11,
              color: active ? const Color(0xFF2D2D2A) : const Color(0xFF8A857B),
            ),
          ),
        ],
      ),
    );
  }
}

class _CmsPlpBody extends StatelessWidget {
  final CatalogCategory category;
  final CmsPageBundle bundle;
  final bool isSidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;

  const _CmsPlpBody({
    required this.category,
    required this.bundle,
    required this.isSidebarExpanded,
    required this.onSidebarExpandedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nextPosition = bundle.sections.isEmpty
        ? 0
        : (bundle.sections
                  .map((s) => s.record.position)
                  .reduce((a, b) => a > b ? a : b) +
              1);

    // Storefront sections never watch editModeProvider. The edit chrome
    // (sidebar + FAB + sidebar toggle) is the only subtree that does, so
    // toggling edit mode does not tear down the section render objects.
    return Stack(
      fit: StackFit.expand,
      children: [
        _CmsPlpStorefrontSections(
          category: category,
          allSections: bundle.sections,
          pageId: bundle.page.id,
        ),
        _CmsPlpEditChrome(
          pageId: bundle.page.id,
          sections: bundle.sections,
          nextPosition: nextPosition,
          isSidebarExpanded: isSidebarExpanded,
          onSidebarExpandedChanged: onSidebarExpandedChanged,
        ),
      ],
    );
  }
}

class _CmsPlpStorefrontSections extends StatelessWidget {
  final CatalogCategory category;
  final List<CmsSectionConfig> allSections;
  final String pageId;

  const _CmsPlpStorefrontSections({
    required this.category,
    required this.allSections,
    required this.pageId,
  });

  @override
  Widget build(BuildContext context) {
    final visible = allSections
        .where((s) => s.record.isActive && s is! CmsUnknownSection)
        .toList(growable: false);

    return CustomScrollView(
      slivers: [
        for (final section in visible)
          SliverToBoxAdapter(
            child: CmsEditOverlay(
              section: section,
              allSections: allSections,
              pageId: pageId,
              child: renderCmsSection(
                context,
                section,
                routeCategoryId: category.id,
                routeCategory: category,
                // This is the true catalogue PLP path
                // (/catalog and /catalog/:categorySlug). Opt the product grid
                // into the PLP→PDP image Hero here; the homepage landing page
                // and other CMS surfaces keep the renderer default (false).
                enableProductHeroTransition: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _CmsPlpEditChrome extends ConsumerWidget {
  final String pageId;
  final List<CmsSectionConfig> sections;
  final int nextPosition;
  final bool isSidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;

  const _CmsPlpEditChrome({
    required this.pageId,
    required this.sections,
    required this.nextPosition,
    required this.isSidebarExpanded,
    required this.onSidebarExpandedChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(editModeProvider);
    final areEditControlsVisible = ref.watch(editControlsVisibleProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isEditMode)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: CmsSectionsSidebar(
              pageId: pageId,
              sections: sections,
              nextPosition: nextPosition,
              isExpanded: isSidebarExpanded,
              onExpandedChanged: onSidebarExpandedChanged,
            ),
          ),
        if (isEditMode && !isSidebarExpanded)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 84,
            left: 12,
            child: CmsSidebarToggleButton(
              isExpanded: false,
              onPressed: () => onSidebarExpandedChanged(true),
            ),
          ),
        if (areEditControlsVisible)
          Positioned(
            right: 16,
            bottom: 16,
            child: _EditModeFab(isEditMode: isEditMode),
          ),
      ],
    );
  }
}

class _EditModeFab extends ConsumerWidget {
  final bool isEditMode;

  const _EditModeFab({required this.isEditMode});

  Future<void> _toggleEditMode(BuildContext context, WidgetRef ref) async {
    if (isEditMode) {
      ref.read(editModeProvider.notifier).state = false;
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    ref.read(editModeProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      backgroundColor: isEditMode
          ? const Color(0xFFA8892E)
          : const Color(0xFF2B2B2B),
      onPressed: () => _toggleEditMode(context, ref),
      child: Icon(
        isEditMode ? Icons.close : Icons.edit,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _ImmersiveHeaderController extends ConsumerStatefulWidget {
  final double? heroHeight;
  final Widget child;

  const _ImmersiveHeaderController({
    required this.heroHeight,
    required this.child,
  });

  @override
  ConsumerState<_ImmersiveHeaderController> createState() =>
      _ImmersiveHeaderControllerState();
}

class _ImmersiveHeaderControllerState
    extends ConsumerState<_ImmersiveHeaderController> {
  late final StorefrontShellNotifier _shellNotifier;

  @override
  void initState() {
    super.initState();
    _shellNotifier = ref.read(storefrontShellProvider.notifier);
    _updateMode();
  }

  @override
  void didUpdateWidget(covariant _ImmersiveHeaderController oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroHeight != widget.heroHeight) {
      _updateMode();
    }
  }

  @override
  void dispose() {
    _shellNotifier.setNormalDeferred();
    super.dispose();
  }

  void _updateMode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final heroHeight = widget.heroHeight;
      if (heroHeight != null) {
        _shellNotifier.setImmersive(
          foregroundColor: Colors.white,
          heroHeight: heroHeight,
        );
      } else {
        _shellNotifier.setNormal();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

double? _heroHeightAtTop(
  BuildContext context,
  List<CmsSectionConfig> visibleSections,
) {
  if (visibleSections.isEmpty) {
    return null;
  }
  final first = visibleSections.first;
  if (first is! CmsHeroSection) {
    return null;
  }
  final size = MediaQuery.sizeOf(context);
  // A 'square' hero is full-bleed 1:1, so its height equals the viewport width.
  if (first.data.heightMode == 'square') {
    return size.width;
  }
  final isTablet = StorefrontLayout.isTabletOnly(size.width);
  final isDesktop = StorefrontLayout.isDesktop(size.width);
  return HeroCampaignSection.heightFor(
    mode: first.data.heightMode,
    viewportHeight: size.height,
    isMobile: !isTablet && !isDesktop,
  );
}
