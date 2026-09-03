import '../admin/admin_backoffice_repository.dart';
import 'drawer_navigation_models.dart';

class NavigationEditorOption {
  final String id;
  final String label;

  const NavigationEditorOption({required this.id, required this.label});
}

class NavigationEditorOptionsBundle {
  final List<NavigationEditorOption> categories;
  final List<NavigationEditorOption> products;
  final List<NavigationEditorOption> medias;

  const NavigationEditorOptionsBundle({
    required this.categories,
    required this.products,
    required this.medias,
  });

  static const empty = NavigationEditorOptionsBundle(
    categories: [],
    products: [],
    medias: [],
  );
}

class LoadNavigationEditorOptions {
  final AdminBackofficeRepository repository;

  const LoadNavigationEditorOptions(this.repository);

  Future<NavigationEditorOptionsBundle> call({
    required String baseUrl,
    required String authToken,
    DrawerNavigationItemData? initialItem,
  }) async {
    final results = await Future.wait([
      repository.listRecords(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'categories',
        sort: 'name',
        perPage: 500,
        filter: 'isActive=true',
      ),
      repository.listRecords(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'products',
        sort: 'name',
        perPage: 500,
        filter: 'isActive=true',
      ),
      repository.listRecords(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'medias',
        sort: 'title',
        perPage: 500,
        filter: 'isActive=true',
      ),
    ]);

    return NavigationEditorOptionsBundle(
      categories: ensureSelectedEditorOption(
        mapEditorOptions(
          results[0],
          fallbackField: 'name',
          secondaryField: 'code',
        ),
        selectedId: initialItem?.categoryId,
        selectedLabel: selectedCategoryLabel(initialItem),
      ),
      products: ensureSelectedEditorOption(
        mapEditorOptions(
          results[1],
          fallbackField: 'name',
          secondaryField: 'code',
        ),
        selectedId: initialItem?.productId,
        selectedLabel: selectedProductLabel(initialItem),
      ),
      medias: ensureSelectedEditorOption(
        mapEditorOptions(
          results[2],
          fallbackField: 'title',
          secondaryField: 'code',
        ),
        selectedId: initialItem?.promoMediaId,
        selectedLabel: selectedMediaLabel(initialItem),
      ),
    );
  }
}

List<NavigationEditorOption> mapEditorOptions(
  List<Map<String, dynamic>> records, {
  required String fallbackField,
  String? secondaryField,
}) {
  return dedupeEditorOptions(
    records
        .map((record) {
          final primary = (record[fallbackField] as String?)?.trim();
          final secondary = secondaryField == null
              ? null
              : (record[secondaryField] as String?)?.trim();
          final label = [
            if (primary != null && primary.isNotEmpty) primary,
            if (secondary != null && secondary.isNotEmpty) secondary,
          ].join(' • ');

          return NavigationEditorOption(
            id: record['id'] as String? ?? '',
            label: label.isEmpty ? (record['id'] as String? ?? '') : label,
          );
        })
        .where((option) => option.id.isNotEmpty)
        .toList(growable: false),
  );
}

List<NavigationEditorOption> dedupeEditorOptions(
  List<NavigationEditorOption> options,
) {
  final byId = <String, NavigationEditorOption>{};
  for (final option in options) {
    byId.putIfAbsent(option.id, () => option);
  }
  return byId.values.toList(growable: false);
}

List<NavigationEditorOption> ensureSelectedEditorOption(
  List<NavigationEditorOption> options, {
  required String? selectedId,
  required String? selectedLabel,
}) {
  final normalizedId = selectedId?.trim();
  if (normalizedId == null || normalizedId.isEmpty) {
    return dedupeEditorOptions(options);
  }

  final deduped = dedupeEditorOptions(options);
  final alreadyPresent = deduped.any((option) => option.id == normalizedId);
  if (alreadyPresent) {
    return deduped;
  }

  return [
    NavigationEditorOption(
      id: normalizedId,
      label: selectedLabel?.trim().isNotEmpty == true
          ? selectedLabel!.trim()
          : 'Selection actuelle • $normalizedId',
    ),
    ...deduped,
  ];
}

String? selectedCategoryLabel(DrawerNavigationItemData? item) {
  final category = item?.category;
  if (category == null) {
    return null;
  }

  final parts = [
    if (category.name.trim().isNotEmpty) category.name.trim(),
    if (category.code.trim().isNotEmpty) category.code.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' • ');
}

String? selectedProductLabel(DrawerNavigationItemData? item) {
  final product = item?.product;
  if (product == null) {
    return null;
  }

  final parts = [
    if (product.name.trim().isNotEmpty) product.name.trim(),
    if (product.code.trim().isNotEmpty) product.code.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' • ');
}

String? selectedMediaLabel(DrawerNavigationItemData? item) {
  final media = item?.promoMedia;
  if (media == null) {
    return null;
  }

  final parts = [
    if ((media.title ?? '').trim().isNotEmpty) media.title!.trim(),
    if (media.id.trim().isNotEmpty) media.id.trim(),
  ];
  return parts.isEmpty ? null : parts.join(' • ');
}
