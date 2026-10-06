const test = require("node:test");
const assert = require("node:assert/strict");
const tools = require("../../ChromeExtension/lib/url-tools.js");

test("normalizes focused platform URLs", () => {
  assert.equal(
    tools.normalizedKnownURL("https://youtu.be/abc123?t=2"),
    "https://www.youtube.com/watch?v=abc123"
  );
  assert.equal(
    tools.normalizedKnownURL("https://www.douyin.com/search/test?modal_id=7664504993885457673"),
    "https://www.douyin.com/video/7664504993885457673"
  );
  assert.equal(
    tools.normalizedKnownURL("https://x.com/name/status/12345/photo/1"),
    "https://x.com/i/status/12345"
  );
  assert.equal(
    tools.normalizedKnownURL("https://www.instagram.com/reels/Chunk8-jurw/?utm_source=test"),
    "https://www.instagram.com/reel/Chunk8-jurw/"
  );
  assert.equal(
    tools.normalizedKnownURL("https://www.instagram.com/instagram/reel/Chunk8-jurw/"),
    "https://www.instagram.com/reel/Chunk8-jurw/"
  );
  assert.equal(
    tools.normalizedKnownURL("https://www.instagram.com/stories/example/3570766765028588805/"),
    "https://www.instagram.com/stories/example/3570766765028588805/"
  );
  assert.equal(
    tools.normalizedKnownURL("https://www.bilibili.com/video/BV1xx411c7mD/?p=2&spm_id_from=333.1007"),
    "https://www.bilibili.com/video/BV1xx411c7mD?p=2"
  );
  assert.equal(
    tools.normalizedKnownURL("https://www.bilibili.com/bangumi/play/ep12345?from_spmid=666"),
    "https://www.bilibili.com/bangumi/play/ep12345"
  );
  assert.equal(
    tools.normalizedKnownURL("https://live.bilibili.com/123456?broadcast_type=0"),
    "https://live.bilibili.com/123456"
  );
  assert.equal(tools.normalizedKnownURL("https://b23.tv/AbCd123?share_source=copy_web"), "https://b23.tv/AbCd123");
  assert.equal(
    tools.normalizedKnownURL("https://www.bilibili.com/video/BV1XyGX6KEYX/?spm_id_from=333.1387.upload.video_card.click"),
    "https://www.bilibili.com/video/BV1XyGX6KEYX"
  );
});

test("creates stable opt-in generic site registrations", () => {
  const first = tools.genericSite("https://example.com/page");
  const second = tools.genericSite("https://example.com/other");
  assert.equal(first.origin, "https://example.com");
  assert.equal(first.pattern, "https://example.com/*");
  assert.equal(first.id, second.id);
  assert.equal(tools.genericSite("chrome://extensions"), null);
});
