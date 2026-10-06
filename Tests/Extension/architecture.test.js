const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");

test("content scripts load shared libraries before the overlay core", () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "ChromeExtension/manifest.json"), "utf8"));
  const scripts = manifest.content_scripts[0].js;
  assert.ok(scripts.indexOf("lib/settings.js") < scripts.indexOf("overlay-core.js"));
  assert.ok(scripts.indexOf("lib/url-tools.js") < scripts.indexOf("overlay-core.js"));
  assert.ok(manifest.permissions.includes("alarms"));
});

test("content tabs never poll or write app preferences", () => {
  const source = fs.readFileSync(path.join(root, "ChromeExtension/overlay-core.js"), "utf8");
  assert.doesNotMatch(source, /app\.getPreferences/);
  assert.doesNotMatch(source, /storage\.sync\.set/);
});

test("floating controls are limited to the middle half of the viewport", () => {
  const source = fs.readFileSync(path.join(root, "ChromeExtension/overlay-core.js"), "utf8");
  assert.match(source, /innerHeight \* 0\.30/);
  assert.match(source, /innerHeight \* 0\.70/);
  assert.match(source, /settings\.scanRegion === "full" \? "0px" : "-30% 0px -30% 0px"/);
});

test("Douyin resolution keeps cookies in the active page", () => {
  const background = fs.readFileSync(path.join(root, "ChromeExtension/background.js"), "utf8");
  const overlay = fs.readFileSync(path.join(root, "ChromeExtension/overlay-core.js"), "utf8");
  assert.match(background, /world: "MAIN"/);
  assert.match(background, /credentials: "include"/);
  assert.match(background, /Douyin's own request middleware/);
  assert.match(background, /mediaURLs: baseCandidates/);
  assert.match(background, /\.\.\.baseCandidates, \.\.\.mediaURLsFromDetail\(apiDetail\)/);
  assert.match(background, /Never replace it with a detail-API/);
  assert.match(background, /args: \[videoID, hintedMediaURL, hintedTitle, playerKind\]/);
  assert.doesNotMatch(background, /performance\.getEntriesByType\("resource"\)/);
  assert.doesNotMatch(background, /\.\.\.domSources/);
  assert.match(background, /window\._ROUTER_DATA/);
  assert.match(background, /window\.__pace_f/);
  assert.match(background, /#RENDER_DATA/);
  assert.match(background, /inspected < 12000/);
  assert.match(background, /embeddedCandidates/);
  assert.match(background, /if \(currentSource && embeddedTitle\)/);
  assert.match(background, /apiDetail\?\.desc \?\? apiDetail\?\.caption/);
  assert.match(overlay, /type: "douyin\.resolve"/);
  assert.match(overlay, /item\.browserResolutionAttempted = true/);
  assert.match(overlay, /mediaElement\?\.currentSrc/);
  assert.match(overlay, /mediaURL: activeMediaURL \?\? null/);
  assert.match(overlay, /title: visibleTitle \?\? null/);
  assert.match(overlay, /playerKind,/);
  assert.match(overlay, /item\.browserResolutionDetail = resolved\.diagnosis/);
  assert.match(overlay, /Array\.isArray\(resolved\.mediaURLs\)/);
  assert.doesNotMatch(background, /extensionAPI\.cookies/);
});
