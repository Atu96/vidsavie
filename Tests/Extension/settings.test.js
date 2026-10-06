const test = require("node:test");
const assert = require("node:assert/strict");
const settings = require("../../ChromeExtension/lib/settings.js");

test("normalizes partial settings", () => {
  assert.deepEqual(settings.normalize({ language: "vi" }), {
    enabled: true,
    showOverlay: true,
    defaultQuality: "best",
    scanRegion: "middle",
    language: "vi",
    theme: "auto",
  });
});

test("migrates retired themes to System", () => {
  assert.equal(settings.normalize({ theme: "aurora" }).theme, "auto");
  assert.equal(settings.normalize({ theme: "unknown" }).theme, "auto");
  assert.equal(settings.normalize({ theme: "dark" }).theme, "dark");
});

test("returns only values that actually changed", () => {
  assert.deepEqual(
    settings.changedValues(
      { ...settings.DEFAULTS, language: "en" },
      { ...settings.DEFAULTS, language: "vi", theme: "dark" }
    ),
    { language: "vi", theme: "dark" }
  );
  assert.equal(settings.isEqual(settings.DEFAULTS, { ...settings.DEFAULTS }), true);
});
