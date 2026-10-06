const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const urlTools = require("../../ChromeExtension/lib/url-tools.js");

const adapterSource = fs.readFileSync(
  path.resolve(__dirname, "../../ChromeExtension/adapters/bilibili.js"),
  "utf8"
);

test("Bilibili video page queues its permalink instead of the blob stream", () => {
  const video = { currentSrc: "blob:https://www.bilibili.com/player-stream" };
  const player = {};
  let adapter;
  const queued = [];
  const document = { querySelector: (selector) => selector === ".bpx-player-container" ? player : null };
  const core = {
    register(value) { adapter = value; },
    normalizedKnownURL(raw) { return urlTools.normalizedKnownURL(raw); },
  };
  const context = {
    document,
    location: {
      href: "https://www.bilibili.com/video/BV1xx411c7mD/?p=2&spm_id_from=333.1007",
      hostname: "www.bilibili.com",
    },
    VideoBatchCore: core,
  };
  context.globalThis = context;
  vm.runInNewContext(adapterSource, context);

  const api = {
    largestVisible(selector, scope) {
      assert.equal(selector, "video");
      assert.equal(scope, player);
      return video;
    },
    queue(target, provider, kind) { queued.push({ target, url: provider(), kind }); },
  };

  assert.equal(adapter.matches(), true);
  const focused = adapter.focus(api);
  assert.equal(focused.active, true);
  assert.equal(focused.target, video);
  adapter.scan(api);
  assert.deepEqual(queued, [{
    target: video,
    url: "https://www.bilibili.com/video/BV1xx411c7mD?p=2",
    kind: "video",
  }]);
});
