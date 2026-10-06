const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '../..', file), 'utf8');
test('popup has one constrained scroll owner, not nested browser and main scrolling', () => {
  const css = read('ChromeExtension/popup.css');
  assert.match(css, /html \{ overflow: hidden;/);
  assert.match(css, /body \{ height: 600px; display: flex; flex-direction: column; overflow: hidden;/);
  assert.ok(!/\b\d+(?:\.\d+)?(?:dvh|svh|lvh|vh)\b/.test(css), 'popup sizing must not depend on the initial browser viewport');
  assert.match(css, /main \{ flex: 1 1 auto; min-height: 0; overflow-y: auto;/);
  assert.equal((css.match(/overflow-y:\s*auto/g) ?? []).length, 1);
  assert.ok(!css.includes('max-height: 470px'));
});
test('quit confirmation is centralized, staying is safe, and support does not terminate', () => {
  const app = read('Sources/VideoBatchDownloader/VideoBatchDownloaderApp.swift');
  const quit = read('Sources/VideoBatchDownloader/QuitConfirmation.swift');
  assert.ok(quit.includes('alert.messageText = "VidSavie"'));
  assert.ok(!quit.includes('Hi there'));
  assert.ok(!quit.includes('👋'));
  assert.ok(app.includes('@NSApplicationDelegateAdaptor(QuitConfirmationDelegate.self)'));
  assert.ok(quit.includes('applicationShouldTerminate'));
  assert.match(quit, /response == \.alertSecondButtonReturn \{ return \.terminateNow \}/);
  assert.match(quit, /alertThirdButtonReturn[\s\S]*https:\/\/ko-fi.com\/atu1202[\s\S]*return \.terminateCancel/);
  assert.ok(quit.includes('alert.buttons[0].keyEquivalent = "\\u{1b}"'));
  assert.ok(quit.includes('alert.window.defaultButtonCell = alert.buttons[0].cell'));
  assert.ok(quit.includes('NSColor.systemRed'));
  for (const code of ['vi', 'zh', 'es', 'fr', 'de', 'pt', 'ja', 'ko']) assert.ok(quit.includes(`case "${code}"`));
});
