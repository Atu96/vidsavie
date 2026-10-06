const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root, file));
test('project grant uses standard GPL text with separate original-code scope', () => {
  const license = read('LICENSE').toString();
  const scope = read('COPYRIGHT').toString();
  assert.ok(license.includes('GNU GENERAL PUBLIC LICENSE'));
  assert.ok(license.includes('Version 3, 29 June 2007'));
  assert.ok(scope.includes('SPDX-License-Identifier: GPL-3.0-or-later'));
  assert.ok(scope.includes('does not assert ownership over yt-dlp, FFmpeg, FFprobe'));
  assert.deepEqual(read('LICENSE'), read('Resources/ThirdParty/GPL-3.0.txt'));
});
test('upstream yt-dlp notices are complete and unmodified', () => {
  assert.equal(crypto.createHash('sha256').update(read('Resources/ThirdParty/YTDLP-THIRD-PARTY-LICENSES.txt')).digest('hex'), '472aefe951c7db35e1657c1d13fd337140511ed6f2b329205105ad441c5a02b7');
  assert.ok(read('Resources/ThirdParty/YTDLP-UNLICENSE.txt').toString().includes('This is free and unencumbered software'));
  assert.ok(read('Resources/ThirdParty/GPL-2.0.txt').toString().includes('Version 2, June 1991'));
});
test('source grant is not misrepresented as completed binary compliance', () => {
  const audit = read('LICENSING-AUDIT.md').toString();
  assert.ok(audit.includes('Status: pending'));
  assert.ok(audit.includes('release/6.1'));
  assert.ok(audit.includes('Managed tool updates'));
  assert.ok(read('README.md').toString().includes('Binary licensing review is still pending'));
});
