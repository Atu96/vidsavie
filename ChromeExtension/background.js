importScripts("lib/settings.js", "lib/url-tools.js");

const extensionAPI = globalThis.browser ?? globalThis.chrome;
const Settings = globalThis.VideoBatchSettings;
const URLTools = globalThis.VideoBatchURLTools;
const APP_ORIGIN = "http://127.0.0.1:17832";
const GENERIC_KEY = "genericSites";
const PREFERENCE_ALARM = "vbd-preference-sync";

function storageGet(defaults) {
  if (globalThis.browser) return extensionAPI.storage.local.get(defaults);
  return new Promise((resolve) => extensionAPI.storage.local.get(defaults, resolve));
}

function storageSet(values) {
  if (globalThis.browser) return extensionAPI.storage.local.set(values);
  return new Promise((resolve) => extensionAPI.storage.local.set(values, resolve));
}

async function registerGeneric(raw, tabId) {
  const site = URLTools.genericSite(raw);
  if (!site || !extensionAPI.scripting?.registerContentScripts) return { ok: false, error: "Unsupported site" };
  try { await extensionAPI.scripting.unregisterContentScripts({ ids: [site.id] }); } catch { /* Not registered yet. */ }
  await extensionAPI.scripting.registerContentScripts([{
    id: site.id,
    matches: [site.pattern],
    js: ["lib/settings.js", "lib/url-tools.js", "overlay-core.js", "adapters/generic-site.js"],
    runAt: "document_idle",
    persistAcrossSessions: true,
  }]);
  const stored = await storageGet({ [GENERIC_KEY]: [] });
  const sites = (stored[GENERIC_KEY] ?? []).filter((item) => item.origin !== site.origin);
  sites.push(site);
  await storageSet({ [GENERIC_KEY]: sites });
  if (Number.isInteger(tabId)) {
    await extensionAPI.scripting.executeScript({
      target: { tabId },
      files: ["lib/settings.js", "lib/url-tools.js", "overlay-core.js", "adapters/generic-site.js"],
    });
  }
  return { ok: true, site };
}

async function unregisterGeneric(raw, tabId) {
  const site = URLTools.genericSite(raw);
  if (!site) return { ok: false, error: "Unsupported site" };
  try { await extensionAPI.scripting?.unregisterContentScripts({ ids: [site.id] }); } catch { /* Already disabled. */ }
  const stored = await storageGet({ [GENERIC_KEY]: [] });
  await storageSet({ [GENERIC_KEY]: (stored[GENERIC_KEY] ?? []).filter((item) => item.origin !== site.origin) });
  if (Number.isInteger(tabId)) {
    try {
      await extensionAPI.scripting.executeScript({ target: { tabId }, func: () => globalThis.VideoBatchCore?.disable?.() });
    } catch { /* The page may have navigated while the popup was open. */ }
  }
  return { ok: true, site };
}

async function requestApp(path, options = {}) {
  // Chrome can wake this service worker a fraction before the local app has
  // finished binding its loopback port. One brief retry prevents a healthy app
  // from being labelled offline, while preserving the one-request UI flow.
  let lastError = null;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      const response = await fetch(`${APP_ORIGIN}${path}`, { cache: "no-store", ...options });
      let data = null;
      try { data = await response.json(); } catch { /* A response body is optional. */ }
      return { ok: response.ok, status: response.status, data, error: response.ok ? null : data?.error ?? `HTTP ${response.status}` };
    } catch (error) {
      lastError = error;
      if (attempt === 0) await new Promise((resolve) => setTimeout(resolve, 500));
    }
  }
  return { ok: false, status: 0, data: null, error: lastError?.message ?? "App offline" };
}

async function syncPreferencesFromApp() {
  const pending = (await storageGet({ pendingSync: false })).pendingSync;
  if (pending) return { ok: true, skipped: "pending local changes" };
  const response = await requestApp("/preferences");
  if (!response.ok) return response;
  const current = await extensionAPI.storage.sync.get(Settings.DEFAULTS);
  const changes = Settings.changedValues(current, response.data);
  if (Object.keys(changes).length > 0) {
    await extensionAPI.storage.sync.set(changes);
  }
  return { ...response, data: Settings.normalize(response.data), changed: Object.keys(changes) };
}

async function resolveDouyinMedia(rawURL, tabId, hintedMediaURL = null, hintedTitle = null, playerKind = "none") {
  const pageURL = URLTools.normalizedKnownURL(rawURL);
  const videoID = pageURL?.match(/\/video\/(\d+)/)?.[1];
  if (!videoID || !Number.isInteger(tabId) || !extensionAPI.scripting?.executeScript) {
    return { ok: false, error: "Douyin tab unavailable", diagnosis: "tab-unavailable" };
  }

  try {
    const results = await extensionAPI.scripting.executeScript({
      target: { tabId },
      world: "MAIN",
      args: [videoID, hintedMediaURL, hintedTitle, playerKind],
      func: async (id, mediaHint, titleHint, playerSourceKind) => {
        const isHTTP = (value) => /^https:\/\//i.test(value ?? "");
        const clickedTitle = titleHint?.replace?.(/\s+/g, " ")?.trim?.() || null;
        const addressURLs = (address) => {
          if (typeof address === "string") return isHTTP(address) ? [address] : [];
          if (Array.isArray(address)) return address.flatMap(addressURLs);
          if (!address || typeof address !== "object") return [];
          return [
            ...addressURLs(address.src),
            ...addressURLs(address.url),
            ...addressURLs(address.url_list ?? address.urlList),
          ].filter(isHTTP);
        };
        const mediaURLsFromDetail = (detail) => {
          const video = detail?.video;
          if (!video) return [];
          const bitRates = video.bit_rate ?? video.bitRate ?? video.bitRateList ?? [];
          return [
            ...addressURLs(video.play_addr ?? video.playAddr),
            ...addressURLs(video.playAddrH265),
            ...bitRates.flatMap((format) => addressURLs(format?.play_addr ?? format?.playAddr)),
            ...addressURLs(video.download_addr ?? video.downloadAddr),
          ].filter(isHTTP);
        };
        const matchingID = (detail) => String(
          detail?.aweme_id ?? detail?.awemeId ?? detail?.awemeIdStr ?? detail?.itemId ?? detail?.groupId ?? ""
        ) === id;
        const findMatchingDetail = (root, playerState = false) => {
          if (!root || typeof root !== "object") return null;
          const queue = [root];
          const visited = new WeakSet();
          let inspected = 0;
          let cursor = 0;
          while (cursor < queue.length && inspected < 12000) {
            const node = queue[cursor++];
            if (!node || typeof node !== "object" || visited.has(node)) continue;
            visited.add(node);
            inspected += 1;
            if (matchingID(node) && mediaURLsFromDetail(node).length > 0) return node;
            let values = [];
            try {
              values = playerState
                ? Object.keys(node).filter((key) => !["children", "return", "stateNode", "_owner"].includes(key)).map((key) => node[key])
                : Object.values(node);
            } catch { /* Ignore guarded page-state properties. */ }
            for (const value of values) {
              if (value && typeof value === "object" && queue.length < 16000) queue.push(value);
            }
          }
          return null;
        };
        const parseSSRText = (raw, layer = 0) => {
          if (typeof raw !== "string" || raw.length > 4_000_000 || !raw.includes(id)) return null;
          // Decode script payloads separately: unrelated HTML can contain a
          // literal percent sign which invalidates decodeURIComponent(page).
          if (layer < 3) {
            for (const match of raw.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script\s*>/gi)) {
              const found = parseSSRText(match[1], layer + 1);
              if (found) return found;
            }
            // Streaming scripts wrap payloads in JSON string literals. Unwrap
            // with JSON.parse only; never execute page-provided JavaScript.
            for (const match of raw.matchAll(/"(?:\\.|[^"\\])*"/g)) {
              if (!match[0].includes(id)) continue;
              try {
                const value = JSON.parse(match[0]);
                if (value !== raw) {
                  const found = parseSSRText(value, layer + 1);
                  if (found) return found;
                }
              } catch { /* Not a JSON string literal. */ }
            }
          }
          let decoded = raw;
          try { decoded = decodeURIComponent(raw); } catch { /* Some chunks are not URI encoded. */ }
          if (!decoded.includes(id) || !/(videoDetail|aweme_detail|playAddr|play_addr)/.test(decoded)) return null;
          try {
            const found = findMatchingDetail(JSON.parse(decoded));
            if (found) return found;
          } catch { /* React streaming chunks can wrap JSON in protocol text. */ }
          // Read only a named detail object; never associate a document-wide
          // CDN URL with the clicked item on an infinite feed.
          const key = /"(?:videoDetail|aweme_detail)"\s*:\s*\{/g;
          for (const match of decoded.matchAll(key)) {
            const start = match.index + match[0].lastIndexOf("{");
            let depth = 0;
            let quoted = false;
            let escaped = false;
            for (let index = start; index < decoded.length; index += 1) {
              const character = decoded[index];
              if (escaped) { escaped = false; continue; }
              if (character === "\\" && quoted) { escaped = true; continue; }
              if (character === '"') { quoted = !quoted; continue; }
              if (quoted) continue;
              if (character === "{") depth += 1;
              if (character === "}" && --depth === 0) {
                try {
                  const detail = JSON.parse(decoded.slice(start, index + 1));
                  if (matchingID(detail) && mediaURLsFromDetail(detail).length > 0) return detail;
                } catch { /* Ignore incomplete or unrelated chunks. */ }
                break;
              }
            }
          }
          return null;
        };

        // Some Douyin players expose only a blob URL even though their signed
        // CDN variants are already present in the page's serialized state.
        // Reading that state is local to the active tab and avoids the broken
        // yt-dlp cookie extractor without exporting any cookie value.
        const embeddedRoots = [
          window._ROUTER_DATA,
          window.__INITIAL_STATE__,
          window.__NEXT_DATA__,
          window.__SSR_DATA__,
        ].filter(Boolean);
        const renderData = document.querySelector("#RENDER_DATA")?.textContent?.trim();
        if (renderData && renderData.length <= 4_000_000) {
          for (const candidate of [renderData, (() => {
            try { return decodeURIComponent(renderData); } catch { return null; }
          })()]) {
            if (!candidate) continue;
            try {
              embeddedRoots.push(JSON.parse(candidate));
              break;
            } catch { /* Try the decoded representation next. */ }
          }
        }
        const paceChunks = Array.isArray(window.__pace_f) ? window.__pace_f : [];
        const scriptChunks = [...document.querySelectorAll("script")]
          .map((script) => script.textContent)
          .filter((value) => typeof value === "string" && value.length <= 4_000_000 && value.includes(id))
          .slice(0, 80);
        // SPA player data can exist only on React's live component props,
        // while global/SSR state is empty. Inspect bounded player ancestors;
        // never accept a source without a detail carrying this exact ID.
        const playerRoots = [];
        const visitedFibers = new WeakSet();
        for (const video of [...document.querySelectorAll("video")].slice(0, 12)) {
          let element = video;
          for (let ancestor = 0; element && ancestor < 12; ancestor++, element = element.parentElement) {
            try {
              const key = Object.keys(element).find((name) => name.startsWith("__reactFiber$"));
              let fiber = key ? element[key] : null;
              for (let depth = 0; fiber && depth < 12 && playerRoots.length < 256; depth++, fiber = fiber.return) {
                if (typeof fiber !== "object" || visitedFibers.has(fiber)) break;
                visitedFibers.add(fiber);
                if (fiber.memoizedProps && typeof fiber.memoizedProps === "object") playerRoots.push(fiber.memoizedProps);
              }
            } catch { /* Page-owned accessors may be unavailable. */ }
          }
        }
        const playerDetail = findMatchingDetail(playerRoots, true);
        const embeddedDetail = playerDetail ?? embeddedRoots.map((root) => findMatchingDetail(root)).find(Boolean)
          ?? [...paceChunks.map((chunk) => chunk?.[1]).filter((value) => typeof value === "string" && value.includes(id)).slice(0, 80), ...scriptChunks]
            .map((value) => parseSSRText(value)).find(Boolean)
          ?? null;
        const embeddedCandidates = mediaURLsFromDetail(embeddedDetail);
        const embeddedTitle = (embeddedDetail?.desc ?? embeddedDetail?.caption)?.replace?.(/\s+/g, " ")?.trim?.() || null;
        const visibleVideos = [...document.querySelectorAll("video")]
          .filter((video) => video.offsetWidth > 0 && video.offsetHeight > 0)
          .sort((left, right) => (right.offsetWidth * right.offsetHeight) - (left.offsetWidth * left.offsetHeight));
        // Do not use document-wide video elements or recent performance URLs
        // as media fallbacks. On an infinite Douyin feed those resources can
        // belong to the previous/next card and silently download the wrong
        // video. Only the clicked element hint or data matched to this ID is
        // allowed to cross into the app.
        const baseCandidates = [...new Set([
          ...(isHTTP(mediaHint) ? [mediaHint] : []),
          ...embeddedCandidates,
        ])];
        const currentSource = baseCandidates[0];

        const visibleVideo = visibleVideos[0];
        const videoRect = visibleVideo?.getBoundingClientRect();
        const titleSelectors = [
          '[data-e2e="video-desc"]',
          '[data-e2e*="video-desc"]',
          '[data-e2e="search-card-desc"]',
          '[class*="video-info"] [class*="title"]',
          '[class*="video-info"] [class*="desc"]',
          '[class*="videoInfo"] [class*="title"]',
          '[class*="videoInfo"] [class*="desc"]',
        ];
        const nearbyTitle = videoRect
          ? titleSelectors
              .flatMap((selector) => [...document.querySelectorAll(selector)])
              .map((element) => {
                const text = element.textContent?.replace(/\s+/g, " ").trim();
                const rect = element.getBoundingClientRect();
                const visible = text && rect.width > 0 && rect.height > 0;
                const distance = Math.abs((rect.left + rect.right) / 2 - (videoRect.left + videoRect.right) / 2)
                  + Math.abs((rect.top + rect.bottom) / 2 - (videoRect.top + videoRect.bottom) / 2);
                return visible ? { text, distance } : null;
              })
              .filter(Boolean)
              .sort((left, right) => left.distance - right.distance)[0]?.text
          : null;

        // The URL already playing in the visible element is the exact signed
        // stream proven to work in this tab. Never replace it with a detail-API
        // candidate merely to obtain metadata; those candidates can have a
        // different anti-hotlink signature and return HTTP 403 outside Chrome.
        if (currentSource && embeddedTitle) {
          return {
            mediaURL: currentSource,
            mediaURLs: baseCandidates,
            title: embeddedTitle,
          };
        }

        // Execute in the page's MAIN world so Douyin's own request middleware
        // adds its short-lived verification signature. Cookies remain inside
        // Chrome and are never returned to the extension or local app.
        let apiDetail = null;
        let apiStatus = "empty";
        try {
          const response = await window.fetch(
            `/aweme/v1/web/aweme/detail/?aweme_id=${encodeURIComponent(id)}`,
            { credentials: "include" }
          );
          const contentType = response.headers?.get?.("content-type") ?? "";
          if (contentType.includes("text/html")) {
            apiStatus = "html";
          } else {
            const payload = await response.json();
            if (payload?.aweme_detail && !matchingID(payload.aweme_detail)) {
              apiStatus = "wrong-id";
            } else {
              apiDetail = payload?.aweme_detail ?? null;
              apiStatus = mediaURLsFromDetail(apiDetail).length > 0 ? "matched" : "empty";
            }
          }
        } catch {
          apiStatus = "failed";
        }
        let mediaURLs = [...new Set([...baseCandidates, ...mediaURLsFromDetail(apiDetail)])].slice(0, 12);
        let htmlStatus = "not-needed";
        let htmlDetail = null;
        if (mediaURLs.length === 0) {
          // A modal/search SPA can lack this video's SSR state while a fresh
          // canonical page contains it. Fetch that page inside the active tab
          // with Chrome's existing session; parse only a matching videoDetail.
          try {
            const response = await window.fetch(`/video/${encodeURIComponent(id)}`, { credentials: "include" });
            const declaredSize = Number(response.headers?.get?.("content-length") ?? 0);
            if (declaredSize > 4_000_000) {
              htmlStatus = "too-large";
            } else {
              const html = await response.text();
              htmlDetail = parseSSRText(html);
              htmlStatus = htmlDetail ? "matched" : "no-match";
              mediaURLs = [...new Set(mediaURLsFromDetail(htmlDetail))].slice(0, 12);
            }
          } catch {
            htmlStatus = "failed";
          }
        }
        const title = (apiDetail?.desc ?? apiDetail?.caption)?.trim()
          || (htmlDetail?.desc ?? htmlDetail?.caption)?.trim()
          || embeddedTitle || clickedTitle || nearbyTitle || null;
        return {
          mediaURL: mediaURLs[0] ?? null,
          mediaURLs,
          title,
          diagnosis: `player-${["https", "blob"].includes(playerSourceKind) ? playerSourceKind : "none"};state-${embeddedDetail ? "matched" : "absent"};api-${apiStatus};html-${htmlStatus}`,
        };
      },
    });
    const resolved = results?.[0]?.result;
    const mediaURLs = [...new Set([
      ...(Array.isArray(resolved?.mediaURLs) ? resolved.mediaURLs : []),
      ...(resolved?.mediaURL ? [resolved.mediaURL] : []),
    ])].slice(0, 12);
    return mediaURLs.length > 0
      ? { ok: true, mediaURL: mediaURLs[0], mediaURLs, title: resolved.title ?? null }
      : { ok: false, error: "Douyin media URL unavailable", diagnosis: resolved?.diagnosis ?? "resolver-empty" };
  } catch (error) {
    return { ok: false, error: error?.message ?? "Douyin media resolution failed", diagnosis: "resolver-error" };
  }
}

function ensurePreferenceAlarm() {
  extensionAPI.alarms?.create(PREFERENCE_ALARM, { delayInMinutes: 1, periodInMinutes: 1 });
}

async function handleMessage(message, sender) {
  switch (message?.type) {
    case "app.health":
      return requestApp("/health");
    case "app.getPreferences":
      return requestApp("/preferences");
    case "app.syncPreferences":
      return syncPreferencesFromApp();
    case "app.setPreferences":
      return requestApp("/preferences", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(message.preferences ?? {}),
      });
    case "app.enqueue":
      return requestApp("/enqueue", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ items: message.items ?? [] }),
      });
    case "douyin.resolve":
      return resolveDouyinMedia(message.url, sender?.tab?.id, message.mediaURL, message.title, message.playerKind);
    case "generic.register":
      return registerGeneric(message.origin, message.tabId);
    case "generic.unregister":
      return unregisterGeneric(message.origin, message.tabId);
    case "generic.status": {
      const site = URLTools.genericSite(message.origin);
      const stored = await storageGet({ [GENERIC_KEY]: [] });
      return { ok: true, enabled: Boolean(site && (stored[GENERIC_KEY] ?? []).some((item) => item.origin === site.origin)), site };
    }
    default:
      return { ok: false, status: 400, error: "Unknown message" };
  }
}

extensionAPI.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message, sender).then(sendResponse, (error) => sendResponse({ ok: false, status: 0, error: error?.message ?? "Unknown error" }));
  return true;
});

extensionAPI.runtime.onInstalled?.addListener(() => {
  ensurePreferenceAlarm();
  void syncPreferencesFromApp();
});
extensionAPI.runtime.onStartup?.addListener(() => {
  ensurePreferenceAlarm();
  void syncPreferencesFromApp();
});
extensionAPI.alarms?.onAlarm.addListener((alarm) => {
  if (alarm.name === PREFERENCE_ALARM) void syncPreferencesFromApp();
});
ensurePreferenceAlarm();
