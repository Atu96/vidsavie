const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const Settings = require('../../ChromeExtension/lib/settings.js');
const I18n = require('../../ChromeExtension/lib/popup-i18n.js');
test('rapid language edits stay selected while older app responses finish', async () => {
  const nodes = new Map();
  const node = key => {
    if (!nodes.has(key)) nodes.set(key, {value: '', dataset: {}, classList: {add(){}, remove(){}, toggle(){}}, addEventListener(){}, setAttribute(){}, querySelector(){return node(key + ' b');}});
    return nodes.get(key);
  };
  const replies = [];
  const sent = [];
  const stored = {};
  const context = vm.createContext({
    VideoBatchSettings: Settings, VideoBatchPopupI18n: I18n,
    browser: {i18n: {getUILanguage: () => 'vi-VN'}, runtime: {sendMessage(message) {
      sent.push(message);
      return new Promise(resolve => replies.push(() => resolve({ok: true, data: message.preferences})));
    }}, storage: {sync: {get: () => new Promise(() => {}), set: async values => Object.assign(stored, values)}, local: {set: async()=>{}, remove: async()=>{}}, onChanged: {addListener(){}}}},
    document: {querySelector: node, querySelectorAll: () => [], documentElement: {dataset: {}}, body: {classList: {toggle(){}}}},
    navigator: {language: 'en-US'}, matchMedia: () => ({matches: false, addEventListener(){}}),
    setTimeout: () => 1, clearTimeout(){}, setInterval(){}, Date,
  });
  vm.runInContext(fs.readFileSync(path.join(__dirname, '../../ChromeExtension/popup.js'), 'utf8'), context);
  const first = vm.runInContext('save("language", "vi")', context);
  const second = vm.runInContext('save("language", "ja")', context);
  const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
  await flush();
  assert.equal(node('#language').value, 'ja');
  assert.equal(sent[0].preferences.language, 'vi');
  replies.shift()(); await flush();
  assert.equal(node('#language').value, 'ja');
  assert.equal(sent[1].preferences.language, 'ja');
  replies.shift()(); await Promise.all([first, second]);
  assert.equal(node('#language').value, 'ja');
  assert.equal(stored.language, 'ja');
});
