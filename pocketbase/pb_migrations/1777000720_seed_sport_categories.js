/// <reference path="../pb_data/types.d.ts" />

// Seeds the Sport storefront category tree as a 3-level hierarchy, with
// sub-categories SPECIFIC to each segment (from the provided screenshots):
//
//   Homme / Femme / Enfant            (roots = "mother" categories = segments)
//     └─ Chaussures / Vêtements / Sport   (mid level, under each segment)
//          └─ Lifestyle, Jordan, …        (leaves — different per segment)
//
// The mid level (Chaussures/Vêtements/Sport) is common to the three segments,
// but each mid's children are segment-specific (e.g. Enfant uses "Éducation
// physique", Femme adds "Brassières de sport" / "Leggings", Homme keeps
// "Skateboard"). These records back the `category_banner_strip` taps: a
// segment's children become banners, and tapping one drills into its children.
//
// Idempotent & additive: a category is matched by its unique `code`; existing
// records (e.g. created from the admin) are reused as parents and never
// overwritten, and only missing nodes are created. Codes/slugs are prefixed by
// the full path so names that repeat across branches/segments stay unique.

const ACCENTS = {
  à: 'a', â: 'a', ä: 'a', á: 'a', ã: 'a',
  ç: 'c',
  é: 'e', è: 'e', ê: 'e', ë: 'e',
  î: 'i', ï: 'i', í: 'i', ì: 'i',
  ô: 'o', ö: 'o', ó: 'o', ò: 'o', õ: 'o',
  û: 'u', ü: 'u', ù: 'u', ú: 'u',
  ÿ: 'y', ñ: 'n',
};

function slugify(value) {
  let out = '';
  const lower = String(value).toLowerCase();
  for (const ch of lower) {
    out += ACCENTS[ch] !== undefined ? ACCENTS[ch] : ch;
  }
  return out.replace(/[^a-z0-9]+/g, '-').replace(/(^-+)|(-+$)/g, '');
}

function codeSuffix(value) {
  return slugify(value).toUpperCase().replace(/-/g, '_');
}

// Root "mother" categories, each with its own mid level (Chaussures /
// Vêtements / Sport) and segment-specific leaves, in drawer order.
const SEGMENTS = [
  {
    code: 'HOMME',
    name: 'Homme',
    slug: 'homme',
    mids: [
      {
        name: 'Chaussures',
        children: [
          'Toutes les chaussures',
          'Lifestyle',
          'Jordan',
          'Running',
          'Football',
          'Basketball',
          'Training et fitness',
          'Skateboard',
          'Chaussures personnalisées',
        ],
      },
      {
        name: 'Vêtements',
        children: [
          'Tous les vêtements',
          'Sweats à capuche et sweats',
          'Hauts et t-shirts',
          'Survêtements',
          'Vestes',
          'Pantalons et leggings',
          'Shorts',
          'Accessoires',
        ],
      },
      {
        name: 'Sport',
        children: [
          'Tous les sports',
          'Running',
          'Football',
          'Basketball',
          'Training et fitness',
          'Tennis',
          'Golf',
        ],
      },
    ],
  },
  {
    code: 'FEMME',
    name: 'Femme',
    slug: 'femme',
    mids: [
      {
        name: 'Chaussures',
        children: [
          'Toutes les chaussures',
          'Lifestyle',
          'Jordan',
          'Running',
          'Training et fitness',
          'Football',
          'Basketball',
          'Chaussures personnalisées',
        ],
      },
      {
        name: 'Vêtements',
        children: [
          'Tous les vêtements',
          'Sweats à capuche et sweats',
          'Hauts et t-shirts',
          'Pantalons',
          'Leggings',
          'Ensembles',
          'Vestes',
          'Shorts',
          'Brassières de sport',
          'Accessoires',
        ],
      },
      {
        name: 'Sport',
        children: [
          'Tous les sports',
          'Running',
          'Football',
          'Basketball',
          'Training et fitness',
          'Tennis',
          'Golf',
        ],
      },
    ],
  },
  {
    code: 'ENFANT',
    name: 'Enfant',
    slug: 'enfant',
    mids: [
      {
        name: 'Chaussures',
        children: [
          'Toutes les chaussures',
          'Lifestyle',
          'Jordan',
          'Football',
          'Running',
          'Basketball',
          'Éducation physique',
        ],
      },
      {
        name: 'Vêtements',
        children: [
          'Tous les vêtements',
          'Sweats à capuche et sweats',
          'Hauts et t-shirts',
          'Pantalons et leggings',
          'Vestes',
          'Survêtements',
          'Shorts',
          'Brassières de sport',
          'Ensembles',
        ],
      },
      {
        name: 'Sport',
        children: ['Running', 'Football', 'Basketball', 'Éducation physique'],
      },
    ],
  },
];

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId('categories');

    const findByCode = (code) => {
      try {
        return app.findFirstRecordByFilter(collection.id, `code = "${code}"`);
      } catch (_) {
        return null;
      }
    };

    const upsert = ({ code, name, slug, parentId, position }) => {
      const existing = findByCode(code);
      if (existing) {
        return existing;
      }
      const record = new Record(collection);
      record.set('code', code);
      record.set('name', name);
      record.set('slug', slug);
      record.set('isActive', true);
      record.set('isHidden', false);
      record.set('position', position);
      if (parentId) {
        record.set('parent', parentId);
      }
      app.save(record);
      return record;
    };

    SEGMENTS.forEach((segment, segmentIndex) => {
      const root = upsert({
        code: segment.code,
        name: segment.name,
        slug: segment.slug,
        parentId: null,
        position: (segmentIndex + 1) * 10,
      });

      segment.mids.forEach((mid, midIndex) => {
        const midCode = `${segment.code}_${codeSuffix(mid.name)}`;
        const midSlug = `${segment.slug}-${slugify(mid.name)}`;
        const midRecord = upsert({
          code: midCode,
          name: mid.name,
          slug: midSlug,
          parentId: root.id,
          position: (midIndex + 1) * 10,
        });

        mid.children.forEach((childName, childIndex) => {
          upsert({
            code: `${midCode}_${codeSuffix(childName)}`,
            name: childName,
            slug: `${midSlug}-${slugify(childName)}`,
            parentId: midRecord.id,
            position: (childIndex + 1) * 10,
          });
        });
      });
    });
  },
  (app) => {
    // Data seed rollback is intentionally a no-op: the up migration is
    // idempotent and may reuse pre-existing categories (which could carry
    // admin-owned products), so deleting here could remove real catalog data.
  },
);
