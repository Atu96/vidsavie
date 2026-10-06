const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.resolve(__dirname,'../..',f),'utf8');
test('main actions share tint-aware hover feedback without geometry changes', () => {
  const view = read('Sources/VideoBatchDownloader/ContentView.swift');
  assert.equal((view.match(/buttonStyle\(AppHoverButtonStyle/g)||[]).length,3);
  const style = read('Sources/VideoBatchDownloader/AppVisuals.swift').split('struct AppHoverButtonStyle:')[1];
  assert.match(style,/onHover/);
  assert.match(style,/colorScheme == \.dark/);
  assert.match(style,/hovering && isEnabled/);
  assert.match(style,/reduceMotion \? nil/);
  assert.ok(!/scaleEffect|offset\(|padding\(|frame\(/.test(style));
  assert.match(style,/allowsHitTesting\(false\)/);
});
