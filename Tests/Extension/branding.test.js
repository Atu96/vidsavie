const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
test('companion artwork differs from the main app at every packaged size', () => {
  for (const [size, icon] of [[16,'icon_16x16'],[32,'icon_32x32'],[128,'icon_128x128'],[1024,'icon_512x512@2x']]) {
    const companion = fs.readFileSync(path.join(root, `ChromeExtension/icons/icon-${size}.png`));
    const app = fs.readFileSync(path.join(root, `Resources/AppIcon.iconset/${icon}.png`));
    assert.equal(companion.readUInt32BE(16), size);
    assert.equal(companion.readUInt32BE(20), size);
    assert.ok(!companion.equals(app));
  }
});
test('About donation link uses the supplied HTTPS destination and red heart', () => {
  const source = fs.readFileSync(path.join(root, 'Sources/VideoBatchDownloader/SettingsView.swift'), 'utf8');
  assert.ok(source.includes('Link(destination: URL(string: "https://ko-fi.com/atu1202")!)'));
  assert.ok(source.includes('Image(systemName: "heart.fill").foregroundStyle(.red)'));
  assert.ok(source.includes('Donate on Ko-fi (opens in browser)'));
  const menu = fs.readFileSync(path.join(root, 'Sources/VideoBatchDownloader/ContentView.swift'), 'utf8');
  assert.ok(menu.includes('Text(t("supportAction", "Support")).foregroundStyle(.primary)'));
  assert.ok(menu.includes('Image(systemName: "heart.fill").foregroundStyle(.red)'));
  assert.ok(menu.includes('NSWorkspace.shared.open(URL(string: "https://ko-fi.com/atu1202")!)'));
});
test('rebrand preserves identity while aligning visible package names and versions', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'ChromeExtension/manifest.json'), 'utf8'));
  const plist = fs.readFileSync(path.join(root, 'Resources/Info.plist'), 'utf8');
  assert.equal(manifest.name, 'VideoFetch Flow');
  assert.match(plist, /CFBundleIdentifier<\/key><string>com.gemst.VideoBatchDownloader<\/string>/);
  assert.match(plist, /CFBundleName<\/key><string>VideoFetch Flow<\/string>/);
  assert.ok(plist.includes(`<string>${manifest.version}</string>`));
  assert.ok(plist.includes('<string>videobatch</string>'));
  assert.match(fs.readFileSync(path.join(root, 'Scripts/build-app.sh'), 'utf8'), /VideoFetch Flow\.app/);
  assert.match(fs.readFileSync(path.join(root, 'Sources/VideoBatchDownloader/SupportToolsInstaller.swift'), 'utf8'), /appendingPathComponent\("Video Batch Downloader"/);
});
