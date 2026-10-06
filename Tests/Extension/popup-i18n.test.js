const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const I18n = require('../../ChromeExtension/lib/popup-i18n.js');
const Settings = require('../../ChromeExtension/lib/settings.js');
test('all nine popup languages cover every visible and accessibility label', () => {
  const html = fs.readFileSync(path.join(__dirname, '../../ChromeExtension/popup.html'), 'utf8');
  const keys = [...html.matchAll(/data-i18n(?:-aria)?="([^"]+)"/g)].map(m => m[1]);
  for (const code of I18n.supported) {
    assert.deepEqual(Object.keys(I18n.dictionaries[code]).sort(), Object.keys(I18n.dictionaries.en).sort());
    for (const key of keys) assert.ok(I18n.dictionaries[code][key], `${code}: ${key}`);
  }
  assert.ok(html.indexOf('lib/popup-i18n.js') < html.indexOf('src="popup.js"'));
});
test('automatic and invalid languages resolve safely', () => {
  assert.equal(I18n.resolveLanguage('auto', 'vi-VN'), 'vi');
  assert.equal(I18n.resolveLanguage('auto', 'zh_CN'), 'zh');
  assert.equal(I18n.resolveLanguage('auto', 'ru-RU'), 'en');
  assert.equal(Settings.normalize({language: 'invalid'}).language, 'auto');
});
