const test = require('node:test');
const assert = require('node:assert/strict');

const dedup = require('../../pocketbase/pb_lib/storefront_settings_dedup.js');

// Test stub for a PocketBase record: only the surface area the dedup
// helpers actually touch (id + getString). Field access goes through
// getString so empty/missing fields return "" like PB does.
function record(id, key, fields) {
  const data = Object.assign({ key: key }, fields || {});
  return {
    id: id,
    getString(field) {
      const value = data[field];
      return value == null ? '' : String(value);
    },
  };
}

test('normalizeTheme: trim + lowercase matches StorefrontTheme.fromWireName', () => {
  assert.equal(dedup.normalizeTheme(' Nike '), 'nike');
  assert.equal(dedup.normalizeTheme('NIKE'), 'nike');
  assert.equal(dedup.normalizeTheme(''), '');
  assert.equal(dedup.normalizeTheme(null), '');
  assert.equal(dedup.normalizeTheme(undefined), '');
});

test('normalizeStyle: trim matches MobileMenuStyle.fromValue', () => {
  assert.equal(dedup.normalizeStyle(' drawer '), 'drawer');
  assert.equal(dedup.normalizeStyle('drawer'), 'drawer');
  // Case-sensitive: matches Dart enum behaviour.
  assert.equal(dedup.normalizeStyle(' DRAWER '), 'DRAWER');
});

test('isValid: brand requires non-empty title AND href after trim', () => {
  assert.equal(
    dedup.isValid(record('r1', 'brand', { brandTitle: 'X', brandHref: '/' }), 'brand'),
    true,
  );
  assert.equal(
    dedup.isValid(record('r1', 'brand', { brandTitle: '   ', brandHref: '/' }), 'brand'),
    false,
    'whitespace-only title is invalid',
  );
  assert.equal(
    dedup.isValid(record('r1', 'brand', { brandTitle: 'X', brandHref: '   ' }), 'brand'),
    false,
    'whitespace-only href is invalid',
  );
  assert.equal(
    dedup.isValid(record('r1', 'brand', { brandTitle: '', brandHref: '' }), 'brand'),
    false,
  );
});

test('isValid: navigation only accepts drawer or fullscreenReveal (after trim)', () => {
  assert.equal(
    dedup.isValid(record('r1', 'navigation', { mobileMenuStyle: 'drawer' }), 'navigation'),
    true,
  );
  assert.equal(
    dedup.isValid(record('r1', 'navigation', { mobileMenuStyle: ' drawer ' }), 'navigation'),
    true,
  );
  assert.equal(
    dedup.isValid(record('r1', 'navigation', { mobileMenuStyle: 'fullscreenReveal' }), 'navigation'),
    true,
  );
  assert.equal(
    dedup.isValid(record('r1', 'navigation', { mobileMenuStyle: 'whatever' }), 'navigation'),
    false,
  );
  assert.equal(
    dedup.isValid(record('r1', 'navigation', { mobileMenuStyle: '' }), 'navigation'),
    false,
  );
});

test('isValid: active_theme only accepts dior or nike (after trim+lowercase)', () => {
  assert.equal(
    dedup.isValid(record('r1', 'active_theme', { theme: 'dior' }), 'active_theme'),
    true,
  );
  assert.equal(
    dedup.isValid(record('r1', 'active_theme', { theme: ' NIKE ' }), 'active_theme'),
    true,
  );
  assert.equal(
    dedup.isValid(record('r1', 'active_theme', { theme: 'foo' }), 'active_theme'),
    false,
  );
  assert.equal(
    dedup.isValid(record('r1', 'active_theme', { theme: '' }), 'active_theme'),
    false,
  );
});

test('isValid returns false for unknown keys', () => {
  assert.equal(dedup.isValid(record('r1', 'mystery', {}), 'mystery'), false);
});

test('resolvedValueFor brand uses JSON, not "|" separator', () => {
  // A title containing "|" would have collided with the old format.
  const a = record('r1', 'brand', { brandTitle: 'Foo|Bar', brandHref: '/x' });
  const b = record('r2', 'brand', { brandTitle: 'Foo', brandHref: 'Bar|/x' });
  assert.notEqual(
    dedup.resolvedValueFor(a, 'brand'),
    dedup.resolvedValueFor(b, 'brand'),
    'JSON.stringify avoids the "|" collision',
  );
});

test('resolvedValueFor normalises before comparing (matches Dart)', () => {
  assert.equal(
    dedup.resolvedValueFor(record('r1', 'active_theme', { theme: ' Nike ' }), 'active_theme'),
    dedup.resolvedValueFor(record('r2', 'active_theme', { theme: 'NIKE' }), 'active_theme'),
  );
  assert.equal(
    dedup.resolvedValueFor(record('r1', 'navigation', { mobileMenuStyle: ' drawer ' }), 'navigation'),
    dedup.resolvedValueFor(record('r2', 'navigation', { mobileMenuStyle: 'drawer' }), 'navigation'),
  );
});

test('decideDedup: empty key records are scheduled for deletion', () => {
  const result = dedup.decideDedup(
    [record('r1', '', {}), record('r2', 'brand', { brandTitle: 'X', brandHref: '/' })],
    500,
  );
  assert.equal(result.abortReason, null);
  assert.deepEqual(result.toDelete, [{ id: 'r1', reason: 'empty_key' }]);
  assert.deepEqual(result.toKeep, [{ id: 'r2', key: 'brand' }]);
});

test('decideDedup: equivalent duplicate active_theme records collapse to one', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'active_theme', { theme: ' Nike ' }),
      record('r2', 'active_theme', { theme: 'NIKE' }),
      record('r3', 'active_theme', { theme: 'nike' }),
    ],
    500,
  );
  assert.equal(result.abortReason, null);
  assert.deepEqual(result.toKeep, [{ id: 'r1', key: 'active_theme' }]);
  assert.equal(result.toDelete.length, 2);
  assert.ok(result.toDelete.every((d) => d.reason === 'duplicate'));
});

test('decideDedup: conflicting active_theme dior vs nike aborts', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'active_theme', { theme: 'dior' }),
      record('r2', 'active_theme', { theme: 'nike' }),
    ],
    500,
  );
  assert.ok(result.abortReason);
  assert.match(result.abortReason, /conflicting values/);
  assert.deepEqual(result.toDelete, []);
});

test('decideDedup: conflicting navigation styles aborts', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'navigation', { mobileMenuStyle: 'drawer' }),
      record('r2', 'navigation', { mobileMenuStyle: 'fullscreenReveal' }),
    ],
    500,
  );
  assert.ok(result.abortReason);
  assert.match(result.abortReason, /conflicting values/);
});

test('decideDedup: equivalent navigation duplicates collapse', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'navigation', { mobileMenuStyle: ' drawer ' }),
      record('r2', 'navigation', { mobileMenuStyle: 'drawer' }),
    ],
    500,
  );
  assert.equal(result.abortReason, null);
  assert.deepEqual(result.toKeep, [{ id: 'r1', key: 'navigation' }]);
  assert.equal(result.toDelete.length, 1);
});

test('decideDedup: brand whitespace-only records are invalid -> abort', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'brand', { brandTitle: '   ', brandHref: '   ' }),
      record('r2', 'brand', { brandTitle: '   ', brandHref: '   ' }),
    ],
    500,
  );
  assert.ok(result.abortReason);
  assert.match(result.abortReason, /failed content validation/);
});

test('decideDedup: brand with two valid but different values aborts', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'brand', { brandTitle: 'Atelier', brandHref: '/' }),
      record('r2', 'brand', { brandTitle: 'Kiki', brandHref: '/home' }),
    ],
    500,
  );
  assert.ok(result.abortReason);
  assert.match(result.abortReason, /conflicting values/);
});

test('decideDedup: unknown duplicated key aborts loudly', () => {
  const result = dedup.decideDedup(
    [record('r1', 'unknown_key', {}), record('r2', 'unknown_key', {})],
    500,
  );
  assert.ok(result.abortReason);
  assert.match(result.abortReason, /unknown key/);
});

test('decideDedup: unknown key with a single record is left alone', () => {
  const result = dedup.decideDedup([record('r1', 'random', {})], 500);
  assert.equal(result.abortReason, null);
  assert.deepEqual(result.toKeep, [{ id: 'r1', key: 'random' }]);
  assert.deepEqual(result.toDelete, []);
});

test('decideDedup: hitting the page cap is treated as truncation -> abort', () => {
  const records = [];
  for (let i = 0; i < 500; i += 1) {
    records.push(record('r' + i, 'brand', { brandTitle: 'X', brandHref: '/' }));
  }
  const result = dedup.decideDedup(records, 500);
  assert.ok(result.abortReason);
  assert.match(result.abortReason, /pagination truncation/);
});

test('decideDedup: single record per known key is kept untouched', () => {
  const result = dedup.decideDedup(
    [
      record('r1', 'brand', { brandTitle: 'Kiki', brandHref: '/' }),
      record('r2', 'navigation', { mobileMenuStyle: 'drawer' }),
      record('r3', 'active_theme', { theme: 'nike' }),
    ],
    500,
  );
  assert.equal(result.abortReason, null);
  assert.equal(result.toKeep.length, 3);
  assert.deepEqual(result.toDelete, []);
});
