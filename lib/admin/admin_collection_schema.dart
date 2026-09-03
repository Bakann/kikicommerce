enum AdminFieldType {
  text,
  multiline,
  boolean,
  integer,
  decimal,
  dateTime,
  relationSingle,
  relationMultiple,
  select,
  file,
}

class AdminFieldDefinition {
  final String name;
  final String label;
  final AdminFieldType type;
  final bool required;
  final String? relationCollection;
  final List<String>? options;
  final bool showInList;

  const AdminFieldDefinition({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.relationCollection,
    this.options,
    this.showInList = true,
  });
}

class AdminCollectionDefinition {
  final String name;
  final String label;
  final String titleField;
  final String sort;
  final List<AdminFieldDefinition> fields;

  const AdminCollectionDefinition({
    required this.name,
    required this.label,
    required this.titleField,
    required this.sort,
    required this.fields,
  });

  List<AdminFieldDefinition> get listFields =>
      fields.where((field) => field.showInList).toList();
}

const adminCollectionDefinitions = <AdminCollectionDefinition>[
  AdminCollectionDefinition(
    name: 'categories',
    label: 'Categories',
    titleField: 'name',
    sort: 'name',
    fields: [
      AdminFieldDefinition(
        name: 'code',
        label: 'Code',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'name',
        label: 'Nom',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'description',
        label: 'Description',
        type: AdminFieldType.multiline,
      ),
      AdminFieldDefinition(
        name: 'slug',
        label: 'Slug',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'parent',
        label: 'Parent',
        type: AdminFieldType.relationSingle,
        relationCollection: 'categories',
      ),
      AdminFieldDefinition(
        name: 'position',
        label: 'Position',
        type: AdminFieldType.integer,
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
      AdminFieldDefinition(
        name: 'isHidden',
        label: 'Masqué du drawer',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'navigation_menus',
    label: 'Navigation Menus',
    titleField: 'name',
    sort: 'code',
    fields: [
      AdminFieldDefinition(
        name: 'name',
        label: 'Nom',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'code',
        label: 'Code',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'displayMode',
        label: 'Mode d’affichage',
        required: true,
        type: AdminFieldType.select,
        options: ['drawer', 'categories'],
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'navigation_items',
    label: 'Navigation Items',
    titleField: 'label',
    sort: 'menu,parent,position',
    fields: [
      AdminFieldDefinition(
        name: 'menu',
        label: 'Menu',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'navigation_menus',
      ),
      AdminFieldDefinition(
        name: 'parent',
        label: 'Parent',
        type: AdminFieldType.relationSingle,
        relationCollection: 'navigation_items',
      ),
      AdminFieldDefinition(
        name: 'position',
        label: 'Position',
        required: true,
        type: AdminFieldType.integer,
      ),
      AdminFieldDefinition(
        name: 'label',
        label: 'Libellé',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'itemType',
        label: 'Type de cible',
        required: true,
        type: AdminFieldType.select,
        options: ['category', 'product', 'page', 'external'],
      ),
      AdminFieldDefinition(
        name: 'category',
        label: 'Catégorie',
        type: AdminFieldType.relationSingle,
        relationCollection: 'categories',
      ),
      AdminFieldDefinition(
        name: 'product',
        label: 'Produit',
        type: AdminFieldType.relationSingle,
        relationCollection: 'products',
      ),
      AdminFieldDefinition(
        name: 'pageKey',
        label: 'Page key',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'url',
        label: 'URL externe',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'promoMedia',
        label: 'Média promo',
        type: AdminFieldType.relationSingle,
        relationCollection: 'medias',
      ),
      AdminFieldDefinition(
        name: 'placement',
        label: 'Placement',
        required: true,
        type: AdminFieldType.select,
        options: ['nav', 'promo'],
      ),
      AdminFieldDefinition(
        name: 'desktopDrawerTemplate',
        label: 'Template desktop',
        type: AdminFieldType.select,
        options: [
          'list_only',
          'hero_single',
          'promo_grid_2x2',
          'promo_stack_2',
        ],
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
      AdminFieldDefinition(
        name: 'isHidden',
        label: 'Masqué',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'products',
    label: 'Products',
    titleField: 'name',
    sort: 'name',
    fields: [
      AdminFieldDefinition(
        name: 'code',
        label: 'Code',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'name',
        label: 'Nom',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'slug',
        label: 'Slug',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'summary',
        label: 'Résumé',
        type: AdminFieldType.multiline,
      ),
      AdminFieldDefinition(
        name: 'description',
        label: 'Description',
        type: AdminFieldType.multiline,
      ),
      AdminFieldDefinition(
        name: 'ean',
        label: 'EAN',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'gender',
        label: 'Genre',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'productType',
        label: 'Type',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'brand',
        label: 'Marque',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'onlineDate',
        label: 'Mise en ligne',
        type: AdminFieldType.dateTime,
      ),
      AdminFieldDefinition(
        name: 'offlineDate',
        label: 'Retrait',
        type: AdminFieldType.dateTime,
      ),
      AdminFieldDefinition(
        name: 'picture',
        label: 'Image principale',
        type: AdminFieldType.relationSingle,
        relationCollection: 'medias',
      ),
      AdminFieldDefinition(
        name: 'thumbnail',
        label: 'Miniature',
        type: AdminFieldType.relationSingle,
        relationCollection: 'medias',
      ),
      AdminFieldDefinition(
        name: 'galleryImages',
        label: 'Galeries',
        type: AdminFieldType.relationMultiple,
        relationCollection: 'mediaContainers',
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'categoryProducts',
    label: 'Category Products',
    titleField: 'id',
    sort: 'category,position',
    fields: [
      AdminFieldDefinition(
        name: 'category',
        label: 'Catégorie',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'categories',
      ),
      AdminFieldDefinition(
        name: 'product',
        label: 'Produit',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'products',
      ),
      AdminFieldDefinition(
        name: 'position',
        label: 'Position',
        type: AdminFieldType.integer,
      ),
      AdminFieldDefinition(
        name: 'isPrimary',
        label: 'Principal',
        type: AdminFieldType.boolean,
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'priceRows',
    label: 'Price Rows',
    titleField: 'id',
    sort: 'product,price',
    fields: [
      AdminFieldDefinition(
        name: 'product',
        label: 'Produit',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'products',
      ),
      AdminFieldDefinition(
        name: 'currency',
        label: 'Devise',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'currencies',
      ),
      AdminFieldDefinition(
        name: 'unit',
        label: 'Unité',
        type: AdminFieldType.relationSingle,
        relationCollection: 'units',
      ),
      AdminFieldDefinition(
        name: 'price',
        label: 'Prix',
        required: true,
        type: AdminFieldType.decimal,
      ),
      AdminFieldDefinition(
        name: 'minqtd',
        label: 'Quantité min',
        type: AdminFieldType.integer,
      ),
      AdminFieldDefinition(
        name: 'net',
        label: 'Net',
        type: AdminFieldType.boolean,
      ),
      AdminFieldDefinition(
        name: 'startTime',
        label: 'Début',
        type: AdminFieldType.dateTime,
      ),
      AdminFieldDefinition(
        name: 'endTime',
        label: 'Fin',
        type: AdminFieldType.dateTime,
      ),
      AdminFieldDefinition(
        name: 'channel',
        label: 'Canal',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'isDefault',
        label: 'Par défaut',
        type: AdminFieldType.boolean,
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'narrativeChapters',
    label: 'Narrative Chapters',
    titleField: 'headline',
    sort: 'product,position',
    fields: [
      AdminFieldDefinition(
        name: 'product',
        label: 'Produit',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'products',
      ),
      AdminFieldDefinition(
        name: 'media',
        label: 'Média',
        required: true,
        type: AdminFieldType.relationSingle,
        relationCollection: 'medias',
      ),
      AdminFieldDefinition(
        name: 'position',
        label: 'Position',
        required: true,
        type: AdminFieldType.integer,
      ),
      AdminFieldDefinition(
        name: 'headline',
        label: 'Titre',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'story',
        label: 'Récit',
        type: AdminFieldType.multiline,
      ),
      AdminFieldDefinition(
        name: 'ctaLabel',
        label: 'Libellé CTA',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'ctaAction',
        label: 'Action CTA',
        type: AdminFieldType.select,
        options: ['zoom', 'sizeGuide', 'materialDetail', 'none'],
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'currencies',
    label: 'Currencies',
    titleField: 'isocode',
    sort: 'isocode',
    fields: [
      AdminFieldDefinition(
        name: 'isocode',
        label: 'ISO',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'symbol',
        label: 'Symbole',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'name',
        label: 'Nom',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'digits',
        label: 'Décimales',
        type: AdminFieldType.integer,
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'units',
    label: 'Units',
    titleField: 'name',
    sort: 'name',
    fields: [
      AdminFieldDefinition(
        name: 'code',
        label: 'Code',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'name',
        label: 'Nom',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'symbol',
        label: 'Symbole',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'medias',
    label: 'Medias',
    titleField: 'title',
    sort: 'title',
    fields: [
      AdminFieldDefinition(
        name: 'code',
        label: 'Code',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'title',
        label: 'Titre',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'altText',
        label: 'Alt text',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'mimeType',
        label: 'MIME type',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'file',
        label: 'Fichier',
        type: AdminFieldType.file,
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
  AdminCollectionDefinition(
    name: 'mediaContainers',
    label: 'Media Containers',
    titleField: 'name',
    sort: 'name',
    fields: [
      AdminFieldDefinition(
        name: 'code',
        label: 'Code',
        required: true,
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'name',
        label: 'Nom',
        type: AdminFieldType.text,
      ),
      AdminFieldDefinition(
        name: 'medias',
        label: 'Médias',
        type: AdminFieldType.relationMultiple,
        relationCollection: 'medias',
      ),
      AdminFieldDefinition(
        name: 'isActive',
        label: 'Actif',
        type: AdminFieldType.boolean,
      ),
    ],
  ),
];

final adminCollectionDefinitionsByName = {
  for (final definition in adminCollectionDefinitions)
    definition.name: definition,
};

String adminRecordLabel(
  AdminCollectionDefinition definition,
  Map<String, dynamic> record,
) {
  final titleCandidate = record[definition.titleField];
  if (titleCandidate is String && titleCandidate.trim().isNotEmpty) {
    return titleCandidate.trim();
  }

  for (final fallbackField in const [
    'label',
    'name',
    'code',
    'pageKey',
    'isocode',
    'title',
    'id',
  ]) {
    final value = record[fallbackField];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return record['id'] as String? ?? 'Sans titre';
}
