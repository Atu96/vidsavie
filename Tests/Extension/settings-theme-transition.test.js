const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
test('settings recreates split hosts on effective theme change without relocating selection state', () => {
  const view = fs.readFileSync(path.resolve(__dirname, '../../Sources/VideoBatchDownloader/SettingsView.swift'), 'utf8');
  assert.match(view, /@State private var section/);
  assert.match(view, /List\(selection: \$section\)/);
  assert.match(view, /\.navigationSplitViewStyle\(\.balanced\)[\s\S]*?\.id\(settingsColorScheme\)[\s\S]*?\.environment\(\\.colorScheme, settingsColorScheme\)/);
  assert.ok(!view.includes('.id(UUID()'));
});
