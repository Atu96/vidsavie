const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const text = file => fs.readFileSync(path.join(root, file), 'utf8');
test('media feed identifies the source archive and reviewed exact binary hashes', () => {
  const feed = JSON.parse(text('Resources/Toolchain/media-release.json'));
  assert.equal(feed.provider, 'vidsavie-source-build');
  assert.equal(feed.version, '9.0.2');
  assert.equal(new URL(feed.archiveURL).hostname, 'github.com');
  assert.ok(feed.sourceURL.includes('/Atu96/vidsavie/releases/download/'));
  for (const key of ['archiveSHA256','sourceSHA256','ffmpegSHA256','ffprobeSHA256']) assert.match(feed[key], /^[a-f0-9]{64}$/);
});
test('bootstrap and managed updates cannot return to the old FFmpeg provider', () => {
  const bootstrap = text('Scripts/prepare-portable-tools.sh');
  const updater = text('Sources/VideoBatchDownloader/SupportToolsInstaller.swift');
  assert.ok(!bootstrap.includes('osxexperts.net'));
  assert.ok(!updater.includes('osxexperts.net'));
  assert.ok(updater.includes('raw.githubusercontent.com/Atu96/vidsavie/main/Resources/Toolchain/media-release.json'));
  assert.ok(updater.indexOf('try sha256(of: payload) == archiveChecksum') < updater.indexOf('arguments: ["-x", "-k", payload.path'));
  assert.ok(updater.includes('stagedSnapshot.ffmpegVersion == manifest.ffmpegVersion'));
  assert.ok(updater.includes('sourceSHA256'));
  assert.ok(text('Sources/VideoBatchDownloader/MediaToolCore.swift').includes('ReviewedMediaPolicy.isReviewedDirectory'));
});
test('source recipe has a controlled LGPL profile and all required app capabilities', () => {
  const recipe = text('Scripts/build-media-toolchain.sh');
  for (const flag of ['--disable-autodetect','--disable-gpl','--disable-nonfree','--enable-securetransport','--enable-libmp3lame','--enable-libdav1d','--enable-videotoolbox']) assert.ok(recipe.includes(flag));
  assert.ok(text('Resources/ThirdParty/MEDIA-TOOLCHAIN.md').includes('LAME'));
  assert.ok(text('Resources/ThirdParty/DAV1D-BSD-2-Clause.txt').includes('VideoLAN'));
});
