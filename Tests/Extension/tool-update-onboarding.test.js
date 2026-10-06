const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.resolve(__dirname, '../..', name), 'utf8');
test('bundled tools are ready and startup checks never install without consent', () => {
  const manager = read('Sources/VideoBatchDownloader/DownloadManager.swift');
  assert.match(manager, /supportToolsInstalled = SupportToolsInstaller.hasAvailableTools\(\)/);
  assert.ok(!manager.includes('refreshSupportToolsState()\n            if supportToolsInstalled'));
  assert.match(manager, /if force \{[\s\S]*?installOrUpdate[\s\S]*?else if try await supportToolsInstaller.updateIsAvailable/);
  assert.match(manager, /alert.runModal\(\) == .alertFirstButtonReturn.*scheduleSupportToolsUpdate\(force: true\)/);
  assert.match(manager, /alert.buttons\[1\].keyEquivalent = "\\r"/);
});
test('metadata-only check compares managed or bundled provenance and ships bundled records', () => {
  const installer = read('Sources/VideoBatchDownloader/SupportToolsInstaller.swift');
  const check = installer.split('func updateIsAvailable()')[1].split('func installOrUpdate(')[0];
  assert.match(check, /fetchManifest/);
  assert.ok(!/stageBinary|download\(|createDirectory|moveItem/.test(check));
  assert.match(check, /sha256\(of:/);
  assert.match(check, /MediaBinaryLocator.ytDlp/);
  const pinned = read('Resources/Toolchain/bundled-yt-dlp.sha256').trim();
  assert.match(pinned, /^[a-f0-9]{64}$/);
  assert.ok(read('Scripts/prepare-portable-tools.sh').includes(pinned));
  assert.match(read('Scripts/build-app.sh'), /Resources\/Toolchain/);
});
test('update prompt has nine languages and leaves current tools usable', () => {
  const copy = read('Sources/VideoBatchDownloader/SupportToolsPromptCopy.swift');
  for (const lang of ['vi','zh','es','fr','de','pt','ja','ko']) assert.ok(copy.includes(`case "${lang}"`));
  assert.ok(copy.includes('The app can still use the tools you already have.'));
});
