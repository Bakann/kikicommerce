/// <reference path="../pb_data/types.d.ts" />

const CMS_PAGES_ID = 'cmspagesv1a000';
const CMS_PAGE_SECTIONS_ID = 'cmspagesecv1a0';

const HOME_SECTION_TYPES = [
  'hero_campaign',
  'editorial_story',
  'category_tiles',
  'featured_products',
  'service_cards',
];

const PLP_SECTION_TYPES = [
  'collection_hero',
  'editorial_intro',
  'mixed_product_grid',
  'seo_text',
  'discover_links',
];

const ALL_SECTION_TYPES = [...HOME_SECTION_TYPES, ...PLP_SECTION_TYPES];

function fieldExists(collection, name) {
  return !!collection.fields.getByName(name);
}

function addFieldIfMissing(collection, name, fieldFactory) {
  if (fieldExists(collection, name)) return;
  const field = fieldFactory();
  collection.fields.add(field);
}

function removeFieldIfPresent(collection, name) {
  const field = collection.fields.getByName(name);
  if (!field) return;
  collection.fields.remove(field);
}

function setSelectValues(collection, fieldName, values) {
  const field = collection.fields.getByName(fieldName);
  if (typeof field.values !== 'undefined') {
    field.maxSelect = 1;
    field.values = values;
  } else {
    field.options = field.options || {};
    field.options.maxSelect = 1;
    field.options.values = values;
  }
}

function addIndexIfMissing(collection, indexSql) {
  collection.indexes = collection.indexes || [];
  if (!collection.indexes.includes(indexSql)) {
    collection.indexes.push(indexSql);
  }
}

migrate(
  (app) => {
    const categoriesId = app.findCollectionByNameOrId('categories').id;

    const pages = app.findCollectionByNameOrId(CMS_PAGES_ID);
    addFieldIfMissing(
      pages,
      'pageType',
      () =>
        new SelectField({
          name: 'pageType',
          required: false,
          maxSelect: 1,
          values: ['home', 'plp', 'content'],
        }),
    );
    addFieldIfMissing(
      pages,
      'sourceCategory',
      () =>
        new RelationField({
          name: 'sourceCategory',
          required: false,
          collectionId: categoriesId,
          maxSelect: 1,
          cascadeDelete: false,
        }),
    );
    addFieldIfMissing(
      pages,
      'seoTitle',
      () =>
        new TextField({
          name: 'seoTitle',
          required: false,
          max: 180,
        }),
    );
    addFieldIfMissing(
      pages,
      'seoDescription',
      () =>
        new TextField({
          name: 'seoDescription',
          required: false,
          max: 320,
        }),
    );
    app.save(pages);

    const pagesWithFields = app.findCollectionByNameOrId(CMS_PAGES_ID);
    addIndexIfMissing(
      pagesWithFields,
      'CREATE INDEX idx_pages_type_category_locale_active ON pages (pageType, sourceCategory, locale, isActive)',
    );
    app.save(pagesWithFields);

    const sections = app.findCollectionByNameOrId(CMS_PAGE_SECTIONS_ID);
    setSelectValues(sections, 'sectionType', ALL_SECTION_TYPES);
    app.save(sections);
  },
  (app) => {
    const pages = app.findCollectionByNameOrId(CMS_PAGES_ID);
    pages.indexes = (pages.indexes || []).filter(
      (indexSql) =>
        indexSql !==
        'CREATE INDEX idx_pages_type_category_locale_active ON pages (pageType, sourceCategory, locale, isActive)',
    );
    app.save(pages);

    const pagesWithoutIndex = app.findCollectionByNameOrId(CMS_PAGES_ID);
    removeFieldIfPresent(pagesWithoutIndex, 'pageType');
    removeFieldIfPresent(pagesWithoutIndex, 'sourceCategory');
    removeFieldIfPresent(pagesWithoutIndex, 'seoTitle');
    removeFieldIfPresent(pagesWithoutIndex, 'seoDescription');
    app.save(pagesWithoutIndex);

    const sections = app.findCollectionByNameOrId(CMS_PAGE_SECTIONS_ID);
    setSelectValues(sections, 'sectionType', HOME_SECTION_TYPES);
    app.save(sections);
  },
);
