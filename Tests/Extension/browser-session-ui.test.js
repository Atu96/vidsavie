const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = f => fs.readFileSync(path.join(__dirname, '../../Sources/VideoBatchDownloader', f), 'utf8');
test('session entry and profile selection are shared and do not export cookies', () => {
  assert.ok(read('SettingsView.swift').includes('settingsLink("session"'));
  for (const f of ['SettingsView.swift', 'SessionRepairView.swift']) assert.ok(read(f).includes('BrowserProfileControl(manager: manager)'));
  const source = read('BrowserProfileControl.swift');
  assert.ok(source.includes('NSOpenPanel()'));
  assert.ok(source.includes('guard response == .OK'));
  assert.ok(source.includes('manager.browserCookieProfile = url.path'));
  assert.ok(!source.includes('contentsOfFile'));
  for (const language of ['en','vi','zh','es','fr','de','pt','ja','ko']) {
    const row = source.split('enum BrowserSessionCopy')[1].match(new RegExp('"'+language+'": \\[(.*)\\]'));
    assert.ok(row, language);
    assert.equal(JSON.parse('['+row[1]+']').length, 9);
  }
  assert.ok(!read('DownloadManager.swift').includes('browserSessionStatus = error.localizedDescription'));
});
test('profile preflight is bounded metadata-only and privacy guidance is consent-based', () => {
  const probe = read('BrowserProfileProbe.swift');
  assert.ok(probe.includes('contentsOfDirectory'));
  assert.ok(probe.includes('inspected < 128'));
  assert.ok(probe.includes('depth < 2'));
  assert.ok(!probe.includes('Data(contentsOf:'));
  assert.ok(!probe.includes('contentsOfFile:'));
  assert.ok(!probe.includes('sqlite3'));
  const source = read('BrowserProfileControl.swift').split('enum BrowserAccessCopy')[1];
  for (const language of ['en','vi','zh','es','fr','de','pt','ja','ko']) {
    const row = source.match(new RegExp('"'+language+'": \\[(.*)\\]'));
    assert.ok(row, language);
    assert.equal(JSON.parse('['+row[1]+']').length, 4);
  }
  assert.ok(read('DownloadEngine.swift').includes('try BrowserProfileProbe.check(configuration)'));
  assert.ok(read('BrowserProfileControl.swift').includes('browserSessionDiagnostic == .accessDenied'));
});
