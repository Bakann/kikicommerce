/// <reference path="../pb_data/types.d.ts" />

// Backfills EN (`locale="en"`) translation rows for catalog content that only
// had French base columns: products, categories, narrative chapters and
// navigation items. The English copy is derived from the FR source. Idempotent:
// skips any (relation, "en") row that already exists, so re-running — and the
// products already translated before this migration — stays safe. The down()
// removes only the rows this migration manages (the record ids listed below).

const LOCALE = 'en';

const CONFIG = [
  { base: 'products', tr: 'product_translations', rel: 'product' },
  { base: 'categories', tr: 'category_translations', rel: 'category' },
  { base: 'narrativeChapters', tr: 'narrative_chapter_translations', rel: 'chapter' },
  { base: 'navigation_items', tr: 'navigation_item_translations', rel: 'item' },
];

const TRANSLATIONS = {
  "products": {
    "ra6tjkbv46mhqyr": {
      "name": "Kiki Atelier Dress",
      "summary": "<p>Light red dress inspired by Kiki.</p>",
      "description": "<p>Soft cotton, relaxed cut, contrast finishes and a discreet pocket.</p>"
    },
    "aokhsveaq4ov77j": {
      "name": "Chihiro Voyage Dress",
      "summary": "<p>Flowing dress designed for travel days.</p>",
      "description": "<p>Supple viscose, a subtle print and a tonal belt.</p>"
    },
    "2pfmr3pdw53mhyy": {
      "name": "Raf and Clauey",
      "summary": "Raf and ClauEy are sitting and talking to each other",
      "description": "<p>Large capacity, reinforced handles and a lightweight lining.</p>"
    },
    "zrxpv4mnf6ajy99": {
      "name": "Calcifer Notebook",
      "summary": "<p>Hardcover notebook in desk format.</p>",
      "description": "<p>Ivory paper, matte cover and a fabric bookmark.</p>"
    },
    "18kkhhi1gppqyca": {
      "name": "Laputa Horizon Throw",
      "summary": "<p>Plush throw in a fine knit.</p>",
      "description": "<p>Soft texture, large format and a sky-blue palette.</p>"
    },
    "ygv33ikqtz0bu9h": {
      "name": "Noiraude Lamp",
      "summary": "<p>Accent lamp with an illustrated shade.</p>",
      "description": "<p>Warm light, a fabric cord and a compact silhouette.</p>"
    },
    "dshqxca78v0bikg": {
      "name": "Nike air Max"
    },
    "p8s9043xuha0spo": {
      "name": "White-on-white Sofa",
      "summary": "More of a couch, really"
    },
    "1ly7a88p4f5o7f1": {
      "name": "Green Bag"
    },
    "idm1nhna6j6vjfu": {
      "name": "Sequin Dress",
      "summary": "Short dress with thin straps, fully covered in sequins for a sparkling, elegant effect. Its fitted cut flatters the figure with a delicate neckline and a fluid line. The black sequined fabric catches the light for a sophisticated finish, ideal for evening wear.\n\nWorn with refined accessories — a structured handbag and understated jewelry — this dress embodies a chic, feminine style, perfect for special occasions or nighttime events.\n\nColor: black with sequins\nCut: short, fitted\nStraps: thin\nMaterial: sequined textile (glossy look)\nStyle: evening / elegant / feminine"
    },
    "etmg79lvr22zogq": {
      "name": "White Bouquet"
    },
    "x0h6322gvakh5eo": {
      "name": "Kawaii",
      "summary": "This sumptuous arrangement elegantly blends powder-pink hydrangeas, roses in peach, coral and soft-yellow tones, and slender white daisies with golden hearts. Touches of wildflowers and fresh green foliage structure the whole, bringing lightness and a natural feel to the composition.\n\nEach flower is carefully selected to create a harmonious balance between generous volumes and delicate details. The soft texture of the petals subtly contrasts with the fineness of the smaller blooms, for a rich and sophisticated visual result.\n\nStyle & mood:\n\nA romantic, springtime spirit\nA bright pastel palette\nChic, natural garden inspiration\nA high-end “freshly picked” effect\n\nIdeal use:\nPerfect to elevate a table, celebrate a special occasion or offer an elegant gesture, this bouquet embodies softness, freshness and refinement all at once.\n\nVisual details:\n\nA dense, balanced composition\nSubtle gradients of pinks, whites and yellows\nSecondary flowers adding finesse and movement\nA natural look with a sophisticated touch\n\nA bouquet that instantly evokes the gentleness of a spring morning, between floral poetry and timeless elegance."
    },
    "secys25ybfpvvs5": {
      "name": "Sakura Light",
      "summary": "A bright, delicate bouquet that captures the essence of a Japanese spring in full bloom. Made of soft-green hydrangeas with pink hues, ivory and cream roses, and fine flowers with powdery accents, this arrangement evokes a stroll beneath the cherry blossoms.\n\nThe whole is wrapped in elegant pastel paper, highlighting the softness of the textures and the subtlety of the colors. Each element seems bathed in golden light, creating an almost dreamlike effect, between poetry and refinement.\n\nStyle & mood:\n\nSakura / Japanese-spring inspiration\nPastel palette: pink, cream, soft green\nWarm, golden light\nA romantic, airy atmosphere\n\nHighlights:\n\nA round, generous composition\nA subtle contrast between voluminous flowers and delicate details\nA “couture bouquet” effect with a careful finish\nIdeal for an elegant gift or a special occasion"
    },
    "9nvaelfmvnpuzwu": {
      "name": "Eternal Lily of the Valley",
      "summary": "An exceptional take on lily of the valley, the emblematic flower of the first bright days, here elevated into a composition of absolute purity.\n\nThis bouquet showcases a profusion of delicate ivory bells, perfectly formed, blossoming in light clouds above a setting of soft-green stems. Hand-tied with a discreet binding, they trace an architectural silhouette, at once dense and airy — the signature of demanding floral craftsmanship.\n\nThe soft, golden light caresses each bloom and reveals the fineness of the textures, while a few petals seem suspended in the air, as if carried by a spring breeze. The backdrop, inspired by a Japanese garden in full bloom, wraps the composition in a poetic, contemplative atmosphere.\n\nCreative intent\nTo evoke the fragile moment when spring settles in, between green freshness and quiet elegance. A tribute to noble simplicity, where every detail counts and nature expresses itself with restraint.\n\nPalette & materials\n\nPearly white, chlorophyll green, diffuse pink hues\nThe satiny texture of the bells, the crisp freshness of the stems\nWarm light, delicate reflections, an almost painterly rendering\n\nSignature\nA rare, timeless bouquet that embodies delicacy, luck and natural elegance all at once — conceived as an exceptional floral piece, between art and emotion."
    },
    "a7qwafv849knvej": {
      "name": "Incandescent Roses",
      "summary": "An exceptional floral piece, where the rose asserts itself in all its splendor, carried by a setting that is both natural and deeply elegant.\n\nNestled in a finely woven wicker basket, deep-red velvety roses bloom into a generous, vibrant composition. Each perfectly open corolla reveals a captivating depth of color — an incandescent, almost luminous red, set off by the vivid green of delicate foliage.\n\nThe structure of the basket, with its soft, enveloping curves, elevates the whole, giving it a handcrafted, timeless dimension. It evokes the gesture of the gatherer, the freshness of the garden at dawn, and that spontaneous elegance found in the finest floral compositions.\n\nBathed in warm, golden light, the composition seems alive, animated by the subtle movement of red petals carried on a gentle breeze. The atmosphere, at once intimate and luminous, evokes a secret garden in full bloom, where every detail contributes to a rare visual emotion.\n\nCreative intent\nTo celebrate the rose in its purest and most expressive form — between intensity, sensuality and controlled naturalness.\n\nPalette & materials\n\nDeep, luminous red\nVivid botanical green\nNatural wicker in honeyed tones\nA play of golden light, satiny reflections on the petals\n\nSignature\nA floral creation with a strong presence, conceived as an object of desire — between sublimated nature and couture aesthetics."
    },
    "vu2d4pz1rgx7r7r": {
      "name": "Mother's Day Peony",
      "summary": "In soft, almost golden light, this peony bouquet reveals all the poetry of a Parisian spring — a gesture conceived as a delicate tribute to Mother's Day. The flowers, wide and generously open, unfold subtle shades of coral pink, delicate blush and cream white. Their finely textured golden hearts catch the light and bring a vibrant depth to the whole.\n\nEach peony seems sculpted, as if shaped by hand, revealing silky petals with airy volumes. The balance between opulence and lightness creates a floral silhouette both contemporary and timeless — a signature of absolute refinement, designed to celebrate, with precision, those who matter.\n\nLook & inspiration:\n\nA floral haute-couture spirit\nA bright, powdery palette\nA play of transparency and texture\nThe evocation of an elegant Parisian spring\nAn exceptional gift for Mother's Day\n\nVisual signature:\nHeld close, the bouquet becomes almost a fashion accessory. It accompanies the gesture, accentuates the silhouette, and turns the moment into a scene. Given as a gift, it conveys sincere emotion, a precious attention. The softness of the tones harmonizes with the skin, while natural light reveals every detail with precision.\n\nSensation:\nA visual fragrance of freshness and grace, between delicacy and intensity. A composition that doesn't try to seduce — it asserts itself with quiet evidence, like a tender, essential gesture."
    },
    "d7v287vmtyyteb6": {
      "name": "White Peony"
    },
    "vuny4stacx2bxzy": {
      "name": "Silent Tension, Absolute Denim",
      "summary": "A raw, almost instinctive look. Here denim becomes a second skin, sculpting the figure with sensual precision. Worn with a simple fitted t-shirt, it reveals all its power: clean lines, a nonchalant attitude, effortless masculinity.\n\nInspired by the icons of the '90s, this pair of jeans captures the essence of a free, assertive style. Between tension and ease, every movement becomes a statement; minimalist, yet unforgettable.\n\nThe kind of piece that doesn't follow the trend, but defines it."
    },
    "t0aogw15y4kf208": {
      "name": "Billie Jean",
      "summary": "A suspended, almost stolen scene, where denim becomes language. Straight cut, natural waist, raw canvas: the jeans structure the figure with timeless ease. Paired with a soft jacket and an immaculate t-shirt, they embody that instinctive elegance of the '60s.\n\nAttitude is everything: nonchalant, magnetic, slightly rebellious. Denim doesn't just dress — it tells a story; a moment, a tension, a complicity. Between shadow and light, it commands a free, authentic, deeply modern look.\n\nAn essential that crosses eras without ever losing its power of attraction."
    },
    "51g1u5f2m3bys6b": {
      "name": "Body & Denim",
      "summary": "Denim as a manifesto. Low waist, authentic canvas, straight cut: a pure architecture that hugs the body without constraining it. Worn against the skin, it reveals an assertive, instinctive, almost sculptural masculinity.\n\nThe look is frontal, introspective, captured in a suspended moment where strength meets vulnerability. A legacy of '90s campaigns, these jeans embody an uncompromising aesthetic: raw, sensual, essential.\n\nMore than a garment, an attitude. A signature."
    },
    "f9m8530lelfwq7q": {
      "name": "Denim Solitude",
      "summary": "Denim as a manifesto. Low waist, authentic canvas, straight cut: a pure architecture that hugs the body without constraining it. Worn against the skin, it reveals an assertive, instinctive, almost sculptural masculinity.\n\nThe look is frontal, introspective, captured in a suspended moment where strength meets vulnerability. A legacy of '90s campaigns, these jeans embody an uncompromising aesthetic: raw, sensual, essential.\n\nMore than a garment, an attitude. A signature."
    },
    "reyq1m7y3gxtvns": {
      "name": "Eternal Imperial Rose 🌹",
      "summary": "A bouquet conceived as a statement.\nEternal Imperial Rose brings together powdery, fuchsia and deep-red roses in a spectacular composition with couture volumes, inspired by the great Parisian flower houses.\n\nPresented in a satiny red cylindrical box and enhanced by a wide, vivid ribbon, this bouquet strikes the perfect balance between modern romance and editorial sophistication. English roses with generous petals converse with vibrant shades of raspberry, carmine and rosy blush to create an opulent, luminous floral silhouette.\n\nEvery detail evokes the aesthetic of a springtime fashion campaign:\na radiant femininity, delicate textures, a spontaneous elegance.\n\nA creation designed for grand gestures, precious moments and emotions that deserve to be offered with brilliance."
    },
    "tplzgl8va2czaju": {
      "name": "Black Ceremony Suit “Golden Ceremony”",
      "summary": "Conceived as a gala silhouette, this black suit embodies the understated elegance of grand ceremonies. Its structured cut traces a clean, masculine and controlled line, while the satin lapel adds a discreet, almost cinematic touch of light. Worn with an immaculate white shirt and a black bow tie, the ensemble evokes the bearing of a laureate: precise, confident, timeless.\n\nThe contrast between the deep black of the tuxedo and the golden reflections of the stage creates a luxurious aesthetic, ideal for moments when elegance must remain powerful without ever becoming ostentatious. It's an outfit designed for exceptional evenings, award ceremonies, formal dinners or events where every detail counts.\n\nMain piece: black ceremony tuxedo\nStyle: contemporary luxury, gala, red carpet, award night\nCut: fitted, structured, sharp shoulder\nVisible details: satin lapel, buttoned jacket, white shirt, black bow tie\nRecommended accessories: dress watch, cufflinks, black patent shoes\nMood: prestige, victory, European elegance, a golden evening"
    },
    "4tfvxtfw9bl6f8n": {
      "name": "Straw Hat “Caribbean Halo”",
      "summary": "A halo of golden straw for those who turn the sun into a signature.\n\nA radiant, sculptural piece, this straw hat reinvents the summer accessory as a true statement object. Its hand-woven crown evokes Caribbean craftsmanship, while its deliberately tapered brim traces an expressive, almost graphic silhouette. Between tropical nonchalance and iconic presence, it immediately commands an attitude: free, magnetic, luxurious.\n\nWorn with an open white shirt, a gold chain and sun-kissed skin, it becomes more than a simple beach hat: it's an editorial piece, designed to turn a minimalist outfit into a powerful image. Its generous volume frames the face, catches the light and gives the whole a fashionable, sensual and artistic dimension."
    }
  },
  "categories": {
    "6s2lgwg23oh5npw": {
      "name": "Studio Kiki Dresses",
      "description": "A capsule collection of dresses inspired by Kiki heroines."
    },
    "rbgw100o4t1n5d7": {
      "name": "Gifts",
      "description": "Textile accessories and stationery for everyday life."
    },
    "l7sviu5unz63uci": {
      "name": "Castle Decor",
      "description": "Home decor objects and textiles for a poetic atmosphere."
    },
    "gt2svxy0xyuz98t": {
      "name": "Vogue"
    },
    "6l9w3cmiw44t70t": {
      "name": "Gifts for her"
    },
    "rrady2t08fkoe2w": {
      "name": "Flowers"
    },
    "6c0d6mfksm7twt3": {
      "name": "Denim"
    },
    "mabb1cp9u4qsjgu": {
      "name": "Men"
    },
    "akb93kg1d7rgomv": {
      "name": "Shoes"
    },
    "qkdyfqy1og5ci4j": {
      "name": "All shoes"
    },
    "30e8wvbox3t6jbr": {
      "name": "Lifestyle"
    },
    "molmg5ha4azanwc": {
      "name": "Jordan"
    },
    "aghbxawerovxw80": {
      "name": "Running"
    },
    "zco9o6bibg0k24g": {
      "name": "Football"
    },
    "adm11f93ls1t2vl": {
      "name": "Basketball"
    },
    "j88vmy0x9p5k07u": {
      "name": "Training & fitness"
    },
    "ldgp87hovar5y5w": {
      "name": "Skateboarding"
    },
    "ybhd0zk3oqqbxsi": {
      "name": "Custom shoes"
    },
    "vq2vfabzpzak4h0": {
      "name": "Clothing"
    },
    "t505a195oqxgoz8": {
      "name": "All clothing"
    },
    "7iuvyfbpka1g0fj": {
      "name": "Hoodies & sweatshirts"
    },
    "0z0v9eqpfau30et": {
      "name": "Tops & t-shirts"
    },
    "g6164dv6ga01tdu": {
      "name": "Tracksuits"
    },
    "2j4kv8eihnqolrj": {
      "name": "Jackets"
    },
    "grlzplsz59q9zob": {
      "name": "Trousers & leggings"
    },
    "54sbrck7qv6cpbn": {
      "name": "Shorts"
    },
    "nt0lwrn6x9jne7c": {
      "name": "Accessories"
    },
    "o7hmnr0umev3vjv": {
      "name": "Sport"
    },
    "nyj9gujjr0214wa": {
      "name": "All sports"
    },
    "14cvy0li8sch5z3": {
      "name": "Running"
    },
    "s9hehcosdr96l1w": {
      "name": "Football"
    },
    "jrxem8uxpzwpahu": {
      "name": "Basketball"
    },
    "bn76by9771j4hjf": {
      "name": "Training & fitness"
    },
    "22ubw82m0ab7lz3": {
      "name": "Tennis"
    },
    "a7to8jjbdz6ws88": {
      "name": "Golf"
    },
    "l7ligextqcwcjk3": {
      "name": "Women"
    },
    "niyboesw8os4d4w": {
      "name": "Shoes"
    },
    "ob4heofov45uh6q": {
      "name": "All shoes"
    },
    "4p3asmoa56me78n": {
      "name": "Lifestyle"
    },
    "cai3ggzfyp55yu4": {
      "name": "Jordan"
    },
    "t28427b97nm41u8": {
      "name": "Running"
    },
    "116xfosqngj7b9p": {
      "name": "Training & fitness"
    },
    "y26ggc0zy3uyqv2": {
      "name": "Football"
    },
    "2gen4j13tep7r7c": {
      "name": "Basketball"
    },
    "zlfx1udr2z0wzpw": {
      "name": "Custom shoes"
    },
    "uobox3nmx39ewzt": {
      "name": "Clothing"
    },
    "aq5cikl70p8wd5a": {
      "name": "All clothing"
    },
    "dq38u1yp45roifz": {
      "name": "Hoodies & sweatshirts"
    },
    "5eeyzdn2y3lanp2": {
      "name": "Tops & t-shirts"
    },
    "q382dbgc7xv4bld": {
      "name": "Trousers"
    },
    "t9ecfp9tqwyzyxi": {
      "name": "Leggings"
    },
    "ijp6j02x766zyxw": {
      "name": "Sets"
    },
    "53d1aqivvv9re17": {
      "name": "Jackets"
    },
    "e7oij0836i1zicj": {
      "name": "Shorts"
    },
    "1tgac3f84ozgttq": {
      "name": "Sports bras"
    },
    "pdzlnyhrqwjs42v": {
      "name": "Accessories"
    },
    "suomd3090yt0l93": {
      "name": "Sport"
    },
    "25zd6rq8lviwbt2": {
      "name": "All sports"
    },
    "dx9qlayl1tdzhsz": {
      "name": "Running"
    },
    "023yria4tosdrgi": {
      "name": "Football"
    },
    "wyhgumkxs7xkcpc": {
      "name": "Basketball"
    },
    "ys5je7i2a5szgkx": {
      "name": "Training & fitness"
    },
    "gdl1x18r9mmck9a": {
      "name": "Tennis"
    },
    "p87siincc2jgsat": {
      "name": "Golf"
    },
    "2i2q83s1ud38yz7": {
      "name": "Kids"
    },
    "denka5vzmn0se3u": {
      "name": "Shoes"
    },
    "dxtdzubjoy1en1i": {
      "name": "All shoes"
    },
    "kijnj6hck1br3bz": {
      "name": "Lifestyle"
    },
    "xw7a1qpk826z7vy": {
      "name": "Jordan"
    },
    "0uweu01d283cms2": {
      "name": "Football"
    },
    "ra0acmbl2ycrxab": {
      "name": "Running"
    },
    "o3q7n4765uw3o8x": {
      "name": "Basketball"
    },
    "fn9cgwwpgkdd5jq": {
      "name": "Physical education"
    },
    "514lmcxjd1scacm": {
      "name": "Clothing"
    },
    "u4rbqhb9zymrgxw": {
      "name": "All clothing"
    },
    "02udyyqkhar72f9": {
      "name": "Hoodies & sweatshirts"
    },
    "nwiywjcsdyd5p6a": {
      "name": "Tops & t-shirts"
    },
    "a97nzjifpd6erjz": {
      "name": "Trousers & leggings"
    },
    "p7cemkg3stxufvc": {
      "name": "Jackets"
    },
    "4fbajz7f8drrt61": {
      "name": "Tracksuits"
    },
    "nzasgxdyd2z4jde": {
      "name": "Shorts"
    },
    "zrbmxgv8hziaey4": {
      "name": "Sports bras"
    },
    "ewov85y940z9af8": {
      "name": "Sets"
    },
    "l8ijdybs09rk6gb": {
      "name": "Sport"
    },
    "19klylrfj8bmbsg": {
      "name": "Running"
    },
    "yyh2mhacb9url3i": {
      "name": "Football"
    },
    "u4oomont6cypuhw": {
      "name": "Basketball"
    },
    "cy499kw4xn42xzk": {
      "name": "Physical education"
    },
    "rcww3ria005lwsp": {
      "name": "Summer essentials"
    },
    "j31qkpsasv9sl4o": {
      "name": "Ballon d'Or"
    },
    "pjh64wbjulwhgct": {
      "name": "Bunny Hope"
    }
  },
  "narrativeChapters": {
    "l07ut5lta7g5x62": {
      "headline": "Kiki takes flight",
      "story": "The silhouette sets in from the very first image and opens the story.",
      "ctaLabel": "Zoom in on the dress"
    },
    "cl7zpv4kenen5x6": {
      "headline": "The fabric follows the wind",
      "story": "Next, we guide you toward the fabric and the movement of the cloth.",
      "ctaLabel": "Fabric details"
    },
    "5uzkzh0sx4qn3s3": {
      "headline": "The dress reads from behind",
      "story": "The last image emphasizes the cut and invites you to check the size.",
      "ctaLabel": "Size guide"
    }
  },
  "navigation_items": {
    "txcaeu7k69lci7r": {
      "label": "Girls' fashion"
    },
    "b5yhwecs6afd684": {
      "label": "Men's fashion"
    },
    "xx6my289zgrzztf": {
      "label": "Dresses"
    },
    "xk5isu3l0gz0vq7": {
      "label": "Flower toys"
    }
  }
};

migrate(
  (app) => {
    for (const cfg of CONFIG) {
      const rows = TRANSLATIONS[cfg.base] || {};
      const ids = Object.keys(rows);
      if (ids.length === 0) continue;
      const collection = app.findCollectionByNameOrId(cfg.tr);
      for (const recordId of ids) {
        let existing = null;
        try {
          existing = app.findFirstRecordByFilter(
            collection.id,
            cfg.rel + ' = "' + recordId + '" && locale = "' + LOCALE + '"',
          );
        } catch (_) {
          existing = null;
        }
        if (existing) continue; // already translated — never overwrite

        const record = new Record(collection);
        record.set(cfg.rel, recordId);
        record.set('locale', LOCALE);
        const fields = rows[recordId];
        for (const field of Object.keys(fields)) {
          record.set(field, fields[field]);
        }
        app.save(record);
      }
    }
  },
  (app) => {
    for (const cfg of CONFIG) {
      const rows = TRANSLATIONS[cfg.base] || {};
      const ids = Object.keys(rows);
      if (ids.length === 0) continue;
      const collection = app.findCollectionByNameOrId(cfg.tr);
      for (const recordId of ids) {
        try {
          const record = app.findFirstRecordByFilter(
            collection.id,
            cfg.rel + ' = "' + recordId + '" && locale = "' + LOCALE + '"',
          );
          app.delete(record);
        } catch (_) {
          // nothing to remove
        }
      }
    }
  },
);
