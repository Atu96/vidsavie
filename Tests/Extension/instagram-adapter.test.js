const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const urlTools = require("../../ChromeExtension/lib/url-tools.js");

const adapterSource = fs.readFileSync(
  path.resolve(__dirname, "../../ChromeExtension/adapters/instagram.js"),
  "utf8"
);

test("Instagram direct Reel detects a visible video outside article and dialog", () => {
  const video = {};
  let adapter;
  const queued = [];
  const document = {
    querySelectorAll(selector) {
      if (selector === '[role="dialog"]') return [];
      if (selector === 'article img,[role="dialog"] img') return [];
      if (selector === "article video,[role=dialog] video") return [];
      return [];
    },
  };
  const core = {
    register(value) { adapter = value; },
    linkAround() { return null; },
    normalizedKnownURL(raw) { return urlTools.normalizedKnownURL(raw, "https://www.instagram.com/reel/Chunk8-jurw/"); },
  };
  const context = {
    URL,
    document,
    location: { href: "https://www.instagram.com/reel/Chunk8-jurw/", hostname: "www.instagram.com" },
    VideoBatchCore: core,
  };
  context.globalThis = context;
  vm.runInNewContext(adapterSource, context);

  const api = {
    largestVisible(selector, scope, predicate) {
      assert.equal(selector, "video");
      assert.equal(scope, document);
      assert.equal(predicate(video), true);
      return video;
    },
    queue(target, provider, kind) { queued.push({ target, url: provider(), kind }); },
  };

  const focused = adapter.focus(api);
  assert.equal(focused.active, true);
  assert.equal(focused.target, video);
  adapter.scan(api);
  assert.deepEqual(queued, [{
    target: video,
    url: "https://www.instagram.com/reel/Chunk8-jurw/",
    kind: "video",
  }]);
});
