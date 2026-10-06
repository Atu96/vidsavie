const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.resolve(__dirname, "../../ChromeExtension/background.js"), "utf8");
const videoID = "7688724747735141678";
const pageURL = `https://www.douyin.com/video/${videoID}`;

async function resolveWithPage(page, hint = null, playerKind = "none") {
  let listener;
  const chrome = {
    runtime: {
      onMessage: { addListener: (callback) => { listener = callback; } },
      onInstalled: { addListener() {} },
      onStartup: { addListener() {} },
    },
    alarms: { create() {}, onAlarm: { addListener() {} } },
    scripting: {
      executeScript: async ({ func, args }) => {
        const result = await vm.runInNewContext(`(${func.toString()})(...args)`, {
          args,
          window: page.window,
          document: page.document,
          URL,
          decodeURIComponent,
        });
        return [{ result }];
      },
    },
  };
  const context = {
    chrome,
    importScripts() {},
    VideoBatchSettings: {},
    VideoBatchURLTools: { normalizedKnownURL: (value) => value },
  };
  context.globalThis = context;
  vm.runInNewContext(source, context);
  return new Promise((resolve) => listener(
    { type: "douyin.resolve", url: pageURL, mediaURL: hint, playerKind },
    { tab: { id: 7 } },
    resolve
  ));
}

function makePage({ chunks = [], scripts = [], detail = null, html = null, videos = [] } = {}) {
  return {
    window: {
      __pace_f: chunks,
      fetch: async (url) => {
        if (url.startsWith("/video/")) {
          if (html === null) throw new Error("HTML unavailable");
          return { headers: { get: () => null }, text: async () => html };
        }
        return { json: async () => ({ aweme_detail: detail }) };
      },
    },
    document: {
      querySelector: () => null,
      querySelectorAll: (selector) => selector === "script"
        ? scripts.map((textContent) => ({ textContent }))
        : selector === "video" ? videos : [],
    },
  };
}

test("Douyin resolver reads ID-matched streaming SSR playAddr src", async () => {
  const target = {
    awemeId: videoID,
    desc: "2026年中秋月饼行情怎么样？",
    video: { playAddr: [{ src: "https://v26-web.douyinvod.com/target.mp4" }] },
  };
  const other = {
    awemeId: "7514320075227204902",
    desc: "Wrong video",
    video: { playAddr: [{ src: "https://v26-web.douyinvod.com/other.mp4" }] },
  };
  const chunk = encodeURIComponent(`0:${JSON.stringify({ feed: [other], videoDetail: target })}`);
  const result = await resolveWithPage(makePage({ chunks: [[1, chunk]] }));
  assert.equal(result.ok, true);
  assert.equal(result.mediaURL, "https://v26-web.douyinvod.com/target.mp4");
  assert.equal(result.title, target.desc);
  assert.equal(result.mediaURLs.includes("https://v26-web.douyinvod.com/other.mp4"), false);
});

test("Douyin resolver rejects detail API data for a different video", async () => {
  const result = await resolveWithPage(makePage({ detail: {
    aweme_id: "7514320075227204902",
    video: { play_addr: { url_list: ["https://v26-web.douyinvod.com/other.mp4"] } },
  } }));
  assert.equal(result.ok, false);
  assert.equal(result.mediaURL, undefined);
  assert.equal(result.diagnosis, "player-none;state-absent;api-wrong-id;html-failed");
});

test("Douyin resolver reads an ID-matched SSR script when pace chunks are absent", async () => {
  const target = {
    awemeId: videoID,
    caption: "Correct clip",
    video: { bitRateList: [{ playAddr: [{ src: "https://v11-weba.douyinvod.com/correct.mp4" }] }] },
  };
  const script = `self.__pace_f.push([1, ${JSON.stringify(encodeURIComponent(`0:${JSON.stringify({ videoDetail: target })}`))}]);`;
  const result = await resolveWithPage(makePage({ scripts: [script] }));
  assert.equal(result.ok, true);
  assert.equal(result.mediaURL, "https://v11-weba.douyinvod.com/correct.mp4");
  assert.equal(result.title, "Correct clip");
});

test("Douyin resolver keeps the exact clicked source ahead of SSR alternatives", async () => {
  const target = {
    awemeId: videoID,
    desc: "Correct clip",
    video: { playAddr: [{ src: "https://v26-web.douyinvod.com/alternate.mp4" }] },
  };
  const chunk = encodeURIComponent(`0:${JSON.stringify({ videoDetail: target })}`);
  const exactSource = "https://v26-web.douyinvod.com/current.mp4";
  const result = await resolveWithPage(makePage({ chunks: [[1, chunk]] }), exactSource);
  assert.equal(result.ok, true);
  assert.equal(result.mediaURL, exactSource);
  assert.equal(result.mediaURLs[1], "https://v26-web.douyinvod.com/alternate.mp4");
});

test("Douyin resolver reads a fresh canonical page without accepting adjacent items", async () => {
  const wrong = {
    awemeId: "7514320075227204902",
    video: { playAddr: [{ src: "https://v26-web.douyinvod.com/wrong.mp4" }] },
  };
  const target = {
    awemeId: videoID,
    desc: "Canonical page title",
    video: { playAddr: [{ src: "https://v26-web.douyinvod.com/canonical.mp4" }] },
  };
  const html = `<script>self.__pace_f.push([1,"${encodeURIComponent(`0:${JSON.stringify({ feed: [wrong], videoDetail: target })}`)}"])</script>`;
  const result = await resolveWithPage(makePage({ html }));
  assert.equal(result.ok, true);
  assert.equal(result.mediaURL, "https://v26-web.douyinvod.com/canonical.mp4");
  assert.equal(result.title, "Canonical page title");
  assert.equal(result.mediaURLs.includes("https://v26-web.douyinvod.com/wrong.mp4"), false);
});

test("Douyin resolver reports only bounded status codes when no source is found", async () => {
  const result = await resolveWithPage(makePage({ html: "<html>verification required</html>" }), null, "blob");
  assert.equal(result.ok, false);
  assert.equal(result.diagnosis, "player-blob;state-absent;api-empty;html-no-match");
  assert.equal(result.diagnosis.includes("https://"), false);
});

const regressionDetail = {
  awemeId: videoID,
  desc: "Synthetic fixture only",
  video: { playAddr: [{ src: "https://v26-web.douyinvod.com/fixture.mp4" }] },
};
const streamingScript = (detail) => `self.__pace_f.push([1,${JSON.stringify(encodeURIComponent(`0:${JSON.stringify({ videoDetail: detail })}`))}]);`;

test("Douyin reads ID-matched live player props with blob media and no SSR", async () => {
  const fiber = { memoizedProps: { item: regressionDetail } };
  fiber.return = fiber;
  fiber.memoizedProps.cycle = fiber.memoizedProps;
  const video = { offsetWidth: 0, offsetHeight: 0, parentElement: { "__reactFiber$fixture": fiber } };
  const page = makePage({ videos: [video] });
  page.window.fetch = () => { throw new Error("Matching player props need no network request"); };
  const result = await resolveWithPage(page, null, "blob");
  assert.equal(result.ok, true);
  assert.equal(result.mediaURL, regressionDetail.video.playAddr[0].src);
  assert.equal(result.title, regressionDetail.desc);
});

test("Douyin rejects adjacent player props and metadata-only target IDs", async () => {
  const wrong = { ...regressionDetail, awemeId: "1234567890123456789" };
  const video = { offsetWidth: 0, offsetHeight: 0, "__reactFiber$fixture": {
    memoizedProps: { item: wrong, selected: { awemeId: videoID }, unrelated: wrong.video },
  } };
  const result = await resolveWithPage(makePage({ videos: [video] }), null, "blob");
  assert.equal(result.ok, false);
  assert.equal(result.mediaURL, undefined);
});

test("Douyin tolerates guarded player properties and keeps SSR fallback", async () => {
  const video = { offsetWidth: 0, offsetHeight: 0 };
  Object.defineProperty(video, "__reactFiber$fixture", { enumerable: true, get() { throw new Error("guarded"); } });
  const result = await resolveWithPage(makePage({ videos: [video], scripts: [streamingScript(regressionDetail)] }));
  assert.equal(result.mediaURL, regressionDetail.video.playAddr[0].src);
});

test("Douyin finds matching script after 155 unrelated scripts", async () => {
  const scripts = [...Array(155).fill("void 0;"), streamingScript(regressionDetail)];
  const result = await resolveWithPage(makePage({ scripts }));
  assert.equal(result.mediaURL, regressionDetail.video.playAddr[0].src);
});

test("Douyin isolates encoded SSR from invalid percent escapes elsewhere in HTML", async () => {
  const html = `<html><p>100% complete</p><script>${streamingScript(regressionDetail)}</script></html>`;
  const result = await resolveWithPage(makePage({ html }));
  assert.equal(result.mediaURL, regressionDetail.video.playAddr[0].src);
});

test("Douyin unwraps escaped JSON strings without executing scripts", async () => {
  const script = `self.__pace_f.push([1,${JSON.stringify(`0:${JSON.stringify({ videoDetail: regressionDetail })}`)}]);throw new Error('must not execute')`;
  const result = await resolveWithPage(makePage({ scripts: [script] }));
  assert.equal(result.mediaURL, regressionDetail.video.playAddr[0].src);
});

test("Douyin rejects wrong-ID SSR even when the target ID is elsewhere in HTML", async () => {
  const wrong = { ...regressionDetail, awemeId: "1234567890123456789" };
  const html = `<p>${videoID} 100%</p><script>${streamingScript(wrong)}</script>`;
  const result = await resolveWithPage(makePage({ html }));
  assert.equal(result.ok, false);
  assert.equal(result.mediaURL, undefined);
});

test("Douyin distinguishes HTML API response and still resolves canonical SSR", async () => {
  const page = makePage({ html: `<p>100%</p><script>${streamingScript(regressionDetail)}</script>` });
  const fetchPage = page.window.fetch;
  page.window.fetch = (url) => url.startsWith("/video/") ? fetchPage(url) : Promise.resolve({
    headers: { get: () => "text/html; charset=utf-8" },
    json: () => { throw new Error("HTML must not be parsed as JSON"); },
  });
  const result = await resolveWithPage(page);
  assert.equal(result.mediaURL, regressionDetail.video.playAddr[0].src);
});
