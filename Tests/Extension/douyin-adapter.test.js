const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.resolve(__dirname, "../../ChromeExtension/adapters/douyin.js"),
  "utf8"
);

function loadAdapter(locationHref) {
  let adapter;
  const context = {
    location: { href: locationHref, hostname: "www.douyin.com" },
    document: {},
    VideoBatchCore: { register: (value) => { adapter = value; } },
  };
  context.globalThis = context;
  vm.runInNewContext(source, context);
  return adapter;
}

test("Douyin modal keeps its floating control when the SPA URL loses modal_id", () => {
  const adapter = loadAdapter("https://www.douyin.com/search/cars");
  const video = {};
  let queuedURL;
  const api = {
    normalizedKnownURL: (raw) => raw?.match(/\/video\/(\d+)/)?.[1]
      ? `https://www.douyin.com/video/${raw.match(/\/video\/(\d+)/)[1]}`
      : null,
    linkAround: () => "https://www.douyin.com/video/7577064036594097743",
    largestVisible: (_selector, _scope, predicate) => predicate(video) ? video : null,
    queue: (_video, provider) => { queuedURL = provider(); },
  };

  assert.equal(adapter.focus(api).active, true);
  adapter.scan(api);
  assert.equal(queuedURL, "https://www.douyin.com/video/7577064036594097743");
});
