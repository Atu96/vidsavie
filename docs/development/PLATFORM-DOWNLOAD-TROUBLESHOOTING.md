# Platform download troubleshooting

## Douyin incident: 2026-09-26, fixed in 2.2.31 (133)

### Symptoms and scope

The floating button supplied no verified direct source; yt-dlp fallback reported “Fresh cookies (not necessarily logged in) are needed”. The same public permalink opened the intended video and worked in another downloader. This did not prove expired cookies, a bad permalink, or a transfer-bandwidth problem. Failure occurred during source extraction, before media transfer.

The active investigation used video ID `7593245307493861366`. Earlier attempts used different IDs; do not merge their observations into a single trace. After the new app was installed and Chrome companion visibly reloaded to 2.2.31, the user confirmed a successful download. They did not restate the video ID in that confirmation. Do not claim universal Douyin support or a verified fix for app-pasted links.

### Measured evidence (sanitized, no credentials or media URLs)

| Probe in the browser session | Observation | Meaning / limit |
|---|---|---|
| App-style `/aweme/v1/web/aweme/detail/` request for the target | HTTP 200; `text/html`; 406,049 bytes; target ID absent | Transport success was not a JSON API success. The reason HTML was served was not established. |
| Canonical `/video/{id}` page | HTTP 200; `text/html`; 836,895 bytes; target ID present | There was target-related page data, not proof by itself of a valid media source. |
| Canonical page scripts | Zero-based script index 155 contained the target ID, `__pace_f`, and `videoDetail` marker | Scanning only the first 80 scripts could omit relevant payloads. |
| URI decoding | Whole-page decode failed; isolated matching script decode succeeded | Unrelated invalid percent escapes must not invalidate a separate encoded payload. |
| Temporary response watcher | HTTP 200 with no extracted fields | Inconclusive: did not establish an empty response, correct ID, or expired session. |

Response sizes and script positions are observations, not stable platform contracts. Do not hard-code them. The live diagnostic did not successfully extract a complete detail object before the code change. No raw response, cookie values, HAR, or signed media URLs were retained as fixtures.

### Changes and owning files

- `ChromeExtension/background.js`, `parseSSRText`: isolate script bodies before URI decoding; unwrap JSON string literals using `JSON.parse`, never `eval` or script execution. Wrapper recursion is capped at three layers; input length is capped at 4,000,000 characters (not a byte-accurate network limit).
- Filter scripts and pace chunks by the requested ID before limiting matching candidates to 80. This retains bounded candidate parsing without assuming useful data is near the beginning of the document.
- Preserve exact detail-ID matching before accepting media and app-side media-host allowlisting. A target ID elsewhere in HTML must not authorize a neighboring video's source. No document-wide player or resource-timing media fallback.
- Classify API `text/html` as `api-html`; continue the existing canonical-page fallback instead of trying to parse HTML as JSON. This diagnosis does not itself repair an API or establish why it returned HTML.
- Browser cookies remain in the browser's normal same-origin request handling. No login form, new cookie permission, cookie export, or yt-dlp update was introduced.
- Only browser-assisted floating-button resolution changed. App-pasted URLs still go through the existing yt-dlp flow. Shared YouTube/Bilibili download behavior was not changed.

### Verification and deployment

`Tests/Extension/douyin-resolver.test.js` includes synthetic regressions for late script index 155, invalid percent escapes outside SSR, escaped JSON wrappers without executing code, rejecting another ID when the target occurs elsewhere, and HTML API replies followed by valid canonical SSR. Existing exact-clicked-source priority and wrong-ID tests remain.

Validation: 154 Swift assertions, 24 extension tests, JS syntax checks, release build, strict/deep signature verification, and bundled-tool smoke tests passed. Real downloads remain user-run under the documented testing boundaries; successful user feedback is separate from deterministic test coverage.

Chrome loaded its unpacked companion from the installed app's Resources directory. Updating workspace files alone was insufficient. The signed app bundle was backed up and replaced as a unit, restarted, checked via `/health`, then the extension was reloaded and its displayed version verified. Never patch the installed signed bundle in place. Existing tabs need a refresh to obtain fresh content scripts. Verify the installed version and companion reload separately from the published Release.

## Reusable method for other platforms

### Follow-up: 2026-09-30, 2.2.32 (134)

Video `7293836342922956083` failed on 2.2.31 with `player-blob;state-absent;api-html;html-no-match`. A verified temporary fetch observer captured the exact-ID detail request (HTTP 200, HTML, 406,526 characters, target absent) and canonical page request (HTTP 200, HTML, 821,032 characters, target present). SSR markers alone did not establish playable data. Live React props attached to player ancestors contained a detail with matching `awemeId` and `video` fields including `playAddr`, `playAddrH265`, and `bitRateList`. No field values or media URLs were exported in diagnostics.

The browser resolver now searches those bounded props before SSR/API fallbacks, keeping exact-ID validation and media allowlisting. Synthetic fixtures cover cycles, adjacent-video rejection, metadata-only IDs, and guarded-property fallback. Live download success must be recorded separately after the user tests the installed build. App-pasted links still use yt-dlp; this does not establish a cookie failure or universal Douyin support.

1. Identify the failing stage: permalink normalization, source extraction, media transfer, or final mux/output. Do not diagnose transfer throttling from an extraction failure.
2. Confirm the exact content ID and entry path (floating button versus app paste). SPA/search/modal pages may not carry the same state as canonical pages. Titles, translated text, nearby videos, and blob URLs are not sufficient identity evidence.
3. Inspect actual response metadata before editing parsers: HTTP status, MIME type, size, JSON parse outcome, field names, and a boolean exact-ID match. A 200 reply can be HTML; an empty field list does not prove an empty body. Never log raw bodies, cookies, authorization headers, or signed URLs.
4. If observing page-generated requests, install a temporary bounded observer before the action, verify it actually recorded the relevant request, then restore original functions. Reloading a page removes an in-page observer; old responses cannot be reconstructed merely because a video is playing. Do not make the user repeatedly reopen a video without a ready observer.
5. Parse serialization boundaries separately: HTML script bodies, JSON string wrappers, URI-encoded payloads, then structured objects. Use data parsers, not execution. Bound size, nesting, work, and candidate count; filter relevance before positional caps. Preserve exact identity and host validation at every fallback.
6. Build sanitized synthetic regression fixtures, including wrong/adjacent IDs and malformed payloads. Generalize the diagnostic method, not Douyin field names or endpoints. Inspect each site's real structure before changing its adapter/resolver; keep platform DOM logic in its own adapter.
7. Run local tests and release verification. Verify which extension directory Chrome actually loads, deploy safely, reload, and confirm the displayed version. Separate “tests passed”, “installed”, and “user download succeeded” in the handoff.

Do not add login UI, switch extractors, broaden permissions, disable blockers, or claim cookies expired solely because a fallback extractor prints an authentication-style error. Another tool succeeding proves an alternative path exists for that case, not which implementation it uses.
