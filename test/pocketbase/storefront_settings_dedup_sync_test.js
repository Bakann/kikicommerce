const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// CI drift guard. The migration `1777000560_unique_storefront_settings_key.js`
// keeps a verbatim copy of the dedup helpers from
// `pb_lib/storefront_settings_dedup.js`. This is unavoidable: PocketBase's
// migration JSVM doesn't reliably resolve cross-directory `require`.
//
// The two copies are bracketed by `// BEGIN DEDUP CORE` and
// `// END DEDUP CORE` markers. This test extracts both blocks and asserts
// they are byte-identical, so any change to one without the other fails
// CI loudly instead of waiting for someone to notice in production.

const MARKER_BEGIN = '// BEGIN DEDUP CORE';
const MARKER_END = '// END DEDUP CORE';

function extractCoreBlock(filePath) {
  const source = fs.readFileSync(filePath, 'utf8');
  const beginIdx = source.indexOf(MARKER_BEGIN);
  const endIdx = source.indexOf(MARKER_END);
  if (beginIdx < 0 || endIdx < 0 || endIdx <= beginIdx) {
    throw new Error(
      'Could not find ' +
        MARKER_BEGIN +
        ' / ' +
        MARKER_END +
        ' markers in ' +
        filePath,
    );
  }
  // Include the markers themselves so the test fails if someone deletes
  // them. The block runs from "BEGIN" inclusive to "END" inclusive.
  return source.slice(beginIdx, endIdx + MARKER_END.length);
}

test('dedup core helpers are identical between pb_lib and the migration', () => {
  const repoRoot = path.resolve(__dirname, '..', '..');
  const libPath = path.join(
    repoRoot,
    'pocketbase',
    'pb_lib',
    'storefront_settings_dedup.js',
  );
  const migrationPath = path.join(
    repoRoot,
    'pocketbase',
    'pb_migrations',
    '1777000560_unique_storefront_settings_key.js',
  );

  const libBlock = extractCoreBlock(libPath);
  const migrationBlock = extractCoreBlock(migrationPath);

  assert.equal(
    libBlock,
    migrationBlock,
    'pb_lib/storefront_settings_dedup.js and the migration have drifted. ' +
      'The block between BEGIN/END DEDUP CORE must be byte-identical in ' +
      'both files. Re-copy the canonical block from pb_lib into the migration.',
  );
});
