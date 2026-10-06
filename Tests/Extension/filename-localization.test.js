const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.resolve(__dirname, '../..', file), 'utf8');
test('filename chips use centralized translations with English fallbacks', () => {
  const view = read('Sources/VideoBatchDownloader/SettingsView.swift');
  for (const key of ['filenameComponents','filenameTitle','filenameAuthor','filenameUploadDate']) assert.ok(view.includes(`t("${key}",`));
  assert.ok(!/Text\("Thành phần"\)|nameChip\("(?:Tiêu đề|Tác giả|Ngày đăng)"/.test(view));
});
test('all nine languages cover every filename label', () => {
  const source = read('Sources/VideoBatchDownloader/AppText.swift');
  const block = source.split('private static let filenameTranslations:')[1].split('private static let mediaSourceTranslations:')[0];
  for (const code of ['en','vi','zh','es','fr','de','pt','ja','ko']) {
    const row = block.split(`"${code}": [`)[1]?.split(']')[0];
    assert.ok(row, code);
    for (const key of ['filenameComponents','filenameTitle','filenameAuthor','filenameUploadDate']) assert.match(row, new RegExp(`"${key}": "[^"]+"`));
  }
  assert.ok(source.includes('filenameTranslations[code]?[key]'));
});
