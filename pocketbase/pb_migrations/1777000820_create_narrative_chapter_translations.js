/// <reference path="../pb_data/types.d.ts" />

// Per-locale strings for a PDP narrative chapter. The base narrativeChapters
// record keeps the locale-invariant data (media, position, ctaAction, flags);
// only headline/story/ctaLabel are translated, one row per (chapter, locale),
// with the same active -> base (default-locale) fallback as the other
// translation collections. Public-read / authenticated-write.
const NARRATIVE_CHAPTER_TRANSLATIONS_ID = 'narrativechtr1';

migrate(
  (app) => {
    const chapters = app.findCollectionByNameOrId('narrativeChapters');

    const collection = new Collection({
      id: NARRATIVE_CHAPTER_TRANSLATIONS_ID,
      name: 'narrative_chapter_translations',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE UNIQUE INDEX idx_narrative_tr_chapter_locale ON narrative_chapter_translations (chapter, locale)',
        'CREATE INDEX idx_narrative_tr_locale ON narrative_chapter_translations (locale)',
      ],
      fields: [
        {
          name: 'chapter',
          type: 'relation',
          required: true,
          collectionId: chapters.id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: 'locale',
          type: 'text',
          required: true,
          min: 2,
          max: 5,
          pattern: '^[a-z]{2}(-[a-z]{2})?$',
        },
        {
          name: 'headline',
          type: 'text',
          required: true,
          min: 1,
          max: 500,
        },
        {
          name: 'story',
          type: 'text',
          required: false,
          max: 20000,
        },
        {
          name: 'ctaLabel',
          type: 'text',
          required: false,
          max: 200,
        },
        {
          name: 'created',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: false,
        },
        {
          name: 'updated',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: true,
        },
      ],
    });

    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(
      NARRATIVE_CHAPTER_TRANSLATIONS_ID,
    );
    return app.delete(collection);
  },
);
