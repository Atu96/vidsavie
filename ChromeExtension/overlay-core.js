(() => {
  if (globalThis.VideoBatchCore) return;

  const extensionAPI = globalThis.browser ?? globalThis.chrome;
  const Settings = globalThis.VideoBatchSettings;
  const URLTools = globalThis.VideoBatchURLTools;
  const DEFAULTS = Settings.DEFAULTS;
  const translations = {
    en: { video: "Video", image: "Image", best: "Best", audio: "Original audio", quality: "Choose quality", sending: "Sending…", opening: "Opening app…", queued: "Queued", openApp: "Open menu app" },
    vi: { video: "Video", image: "Ảnh", best: "Tốt nhất", audio: "Audio gốc", quality: "Chọn chất lượng", sending: "Đang gửi…", opening: "Đang mở app…", queued: "Đã thêm", openApp: "Mở app menu bar" },
    zh: { video: "视频", image: "图片", best: "最佳", audio: "原始音频", quality: "选择画质", sending: "发送中…", opening: "正在打开应用…", queued: "已加入", openApp: "打开菜单栏应用" },
    es: { video: "Vídeo", image: "Imagen", best: "Mejor", audio: "Audio original", quality: "Elegir calidad", opening: "Abriendo app…", sending: "Enviando…", queued: "Añadido", openApp: "Abrir app" },
    fr: { video: "Vidéo", image: "Image", best: "Meilleure", audio: "Audio original", quality: "Choisir la qualité", opening: "Ouverture…", sending: "Envoi…", queued: "Ajouté", openApp: "Ouvrir l’app" },
    de: { video: "Video", image: "Bild", best: "Beste", audio: "Originalton", quality: "Qualität wählen", opening: "App wird geöffnet…", sending: "Senden…", queued: "Hinzugefügt", openApp: "App öffnen" },
    pt: { video: "Vídeo", image: "Imagem", best: "Melhor", audio: "Áudio original", quality: "Escolher qualidade", opening: "Abrindo app…", sending: "Enviando…", queued: "Adicionado", openApp: "Abrir app" },
    ja: { video: "動画", image: "画像", best: "最高", audio: "元の音声", quality: "画質を選択", opening: "アプリを開いています…", sending: "送信中…", queued: "追加済み", openApp: "アプリを開く" },
    ko: { video: "비디오", image: "이미지", best: "최고", audio: "원본 오디오", quality: "화질 선택", opening: "앱 여는 중…", sending: "전송 중…", queued: "추가됨", openApp: "앱 열기" },
  };

  let settings = { ...DEFAULTS };
  let scanTimer;
  let positionFrame;
  let layerPromise;
  let rootHost;
  let layerElement;
  let pageEnabled = true;
  let candidates = new WeakMap();
  const overlays = new Map();
  const adapters = [];

  function send(message) {
    if (globalThis.browser) return extensionAPI.runtime.sendMessage(message);
    return new Promise((resolve, reject) => {
      extensionAPI.runtime.sendMessage(message, (response) => {
        const error = extensionAPI.runtime.lastError;
        if (error) reject(new Error(error.message));
        else resolve(response);
      });
    });
  }

  function visible(element, minimumWidth = 100, minimumHeight = 70, margin = 240) {
    if (!element?.isConnected || element.closest?.('[aria-hidden="true"]')) return false;
    const rect = element.getBoundingClientRect();
    return rect.width >= minimumWidth && rect.height >= minimumHeight && rect.bottom >= -margin && rect.top <= innerHeight + margin && rect.right >= 0 && rect.left <= innerWidth;
  }

  // Keep download controls in the visual focus area: the middle half of the
  // viewport. This deliberately ignores the top and bottom quarters.
  function inFocusBand(element) {
    if (settings.scanRegion === "full") return true;
    const rect = element.getBoundingClientRect();
    // A tall card can still intersect the focus band after its leading edge
    // has scrolled away. Hide its control as soon as that top edge exits the
    // viewport, then keep the remaining visibility policy within the band.
    return rect.top >= 0 && rect.bottom > innerHeight * 0.30 && rect.top < innerHeight * 0.70;
  }

  function largestVisible(selector, scope = document, predicate = () => true) {
    let best = null;
    let area = 0;
    scope.querySelectorAll(selector).forEach((element) => {
      const rect = element.getBoundingClientRect();
      const nextArea = rect.width * rect.height;
      if (visible(element, 120, 80, 0) && nextArea > area && predicate(element)) {
        best = element;
        area = nextArea;
      }
    });
    return best;
  }

  function linkAround(element, selector, depthLimit = 10) {
    for (let node = element; node && depthLimit-- > 0; node = node.parentElement) {
      if (node.matches?.(selector) && node.href) return node.href;
      const anchor = node.querySelector?.(selector);
      if (anchor?.href) return anchor.href;
    }
    return null;
  }

  function absoluteURL(raw) {
    return URLTools.absoluteURL(raw, location.href);
  }

  function normalizedKnownURL(raw) {
    return URLTools.normalizedKnownURL(raw, location.href);
  }

  function hasOwnDownloadControl(media) {
    if (media.closest?.('a[download], [data-download], [aria-label*="download" i], [title*="download" i], [aria-label*="tải xuống" i]')) return true;
    const container = media.closest?.('figure, article, [role="dialog"], [class*="media" i], [class*="player" i]');
    if (!container) return false;
    return [...container.querySelectorAll('a,button')].some((control) => {
      const text = `${control.textContent ?? ""} ${control.getAttribute("aria-label") ?? ""} ${control.getAttribute("title") ?? ""}`.trim();
      if (!/(^|\s)(download|save|tải|telecharger|télécharger|descargar|herunterladen)(\s|$)/i.test(text)) return false;
      const a = control.getBoundingClientRect();
      const b = media.getBoundingClientRect();
      return Math.abs(a.top - b.top) < Math.max(b.height, 500) && Math.abs(a.left - b.left) < Math.max(b.width, 700);
    });
  }

  async function ensureLayer() {
    if (rootHost?.isConnected && layerElement) return layerElement;
    if (layerPromise) return layerPromise;
    layerPromise = (async () => {
      const host = document.createElement("div");
      host.id = "vbd-extension-overlay-root";
      host.dataset.version = extensionAPI.runtime.getManifest().version;
      host.style.cssText = "all:initial;position:fixed;inset:0;width:100vw;height:100vh;z-index:2147483646;pointer-events:none;";
      const shadow = host.attachShadow({ mode: "closed" });
      const style = document.createElement("style");
      const response = await fetch(extensionAPI.runtime.getURL("video-overlay.css"));
      style.textContent = await response.text();
      const layer = document.createElement("div");
      layer.className = "vbd-layer";
      shadow.append(style, layer);
      document.documentElement.append(host);
      rootHost = host;
      layerElement = layer;
      return layer;
    })().finally(() => { layerPromise = null; });
    return layerPromise;
  }

  function words() {
    const requested = settings.language === "auto" ? extensionAPI.i18n.getUILanguage() : settings.language;
    return translations[requested.toLowerCase().split("-")[0]] ?? translations.en;
  }

  function theme() {
    if (settings.theme !== "auto") return settings.theme;
    return matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
  }

  function selectedHeight() { return settings.defaultQuality === "best" ? null : Number(settings.defaultQuality); }
  function stop(event) { event.preventDefault(); event.stopPropagation(); event.stopImmediatePropagation(); }

  function pause(milliseconds) {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
  }

  // This uses the app's registered custom URL scheme from the same user click
  // that pressed the floating control. It opens the menu-bar app without
  // replacing the current web page.
  function launchCompanionApp() {
    const launcher = document.createElement("a");
    launcher.href = "videobatch://open";
    launcher.setAttribute("aria-hidden", "true");
    launcher.style.cssText = "position:fixed;width:1px;height:1px;opacity:0;pointer-events:none;";
    document.documentElement.append(launcher);
    launcher.click();
    launcher.remove();
  }

  async function retryAfterAppLaunch(item) {
    launchCompanionApp();
    // Launch time varies by macOS state. Retry a bounded number of times so a
    // real download error never leaves a disabled control indefinitely.
    for (let attempt = 0; attempt < 10; attempt += 1) {
      await pause(650);
      try {
        const response = await send({ type: "app.enqueue", items: [item] });
        if (response?.ok) return response;
        if (response?.status && response.status !== 0) return response;
      } catch { /* The loopback service is still starting. */ }
    }
    return null;
  }

  async function enqueue(url, maximumHeight, kind, button, mediaElement = null) {
    if (!url) return;
    const text = words();
    const label = button.querySelector(".vbd-button-label");
    label.textContent = text.sending;
    button.disabled = true;
    try {
      const item = { url, maxHeight: maximumHeight, kind };
      if (/^https:\/\/www\.douyin\.com\/video\/\d+$/i.test(url)) {
        item.browserResolutionAttempted = true;
        const mediaRect = mediaElement?.getBoundingClientRect?.();
        const visibleTitle = mediaRect
          ? [
              '[data-e2e="video-desc"]',
              '[data-e2e*="video-desc"]',
              '[data-e2e="search-card-desc"]',
              '[class*="video-info"] [class*="title"]',
              '[class*="video-info"] [class*="desc"]',
              '[class*="videoInfo"] [class*="title"]',
              '[class*="videoInfo"] [class*="desc"]',
            ]
              .flatMap((selector) => [...document.querySelectorAll(selector)])
              .map((element) => {
                const text = element.textContent?.replace(/\s+/g, " ").trim();
                const rect = element.getBoundingClientRect();
                const visible = text && rect.width > 0 && rect.height > 0;
                const distance = Math.abs((rect.left + rect.right) / 2 - (mediaRect.left + mediaRect.right) / 2)
                  + Math.abs((rect.top + rect.bottom) / 2 - (mediaRect.top + mediaRect.bottom) / 2);
                return visible ? { text, distance } : null;
              })
              .filter(Boolean)
              .sort((left, right) => left.distance - right.distance)[0]?.text
          : null;
        if (visibleTitle) item.title = visibleTitle;
        const activeMediaURL = [
          mediaElement?.currentSrc,
          mediaElement?.src,
          mediaElement?.querySelector?.("source")?.src,
        ].find((value) => /^https:\/\//i.test(value ?? ""));
        const playerKind = activeMediaURL ? "https"
          : /^blob:/i.test(mediaElement?.currentSrc ?? mediaElement?.src ?? "") ? "blob" : "none";
        // Preserve the exact stream attached to the button target even if the
        // background worker is stale, sleeping, or cannot inspect this SPA
        // frame. The app independently validates its CDN host before use.
        if (activeMediaURL) {
          item.mediaURL = activeMediaURL;
          item.mediaURLs = [activeMediaURL];
        }
        try {
          const resolved = await send({
            type: "douyin.resolve",
            url,
            mediaURL: activeMediaURL ?? null,
            title: visibleTitle ?? null,
            playerKind,
          });
          if (resolved?.ok && resolved.mediaURL) {
            item.mediaURLs = [...new Set([
              ...(item.mediaURLs ?? []),
              ...(Array.isArray(resolved.mediaURLs) ? resolved.mediaURLs : []),
              resolved.mediaURL,
            ])].slice(0, 12);
            item.mediaURL = item.mediaURLs[0];
            if (resolved.title) item.title = resolved.title;
          } else if (resolved?.diagnosis) {
            item.browserResolutionDetail = resolved.diagnosis;
          }
        } catch {
          item.browserResolutionDetail = "resolver-error";
        }
      }
      let response = await send({ type: "app.enqueue", items: [item] });
      if (!response?.ok && (!response?.status || response.status === 0)) {
        label.textContent = text.opening ?? translations.en.opening;
        response = await retryAfterAppLaunch(item);
      }
      if (!response?.ok) throw new Error(response?.error ?? "offline");
      label.textContent = `✓ ${text.queued}`;
      button.classList.add("vbd-success");
    } catch {
      label.textContent = text.openApp;
      button.classList.add("vbd-error");
    }
    setTimeout(() => {
      label.textContent = kind === "image" ? words().image : words().video;
      button.disabled = false;
      button.classList.remove("vbd-success", "vbd-error");
    }, 2200);
  }

  async function createOverlay(target, provider, kind) {
    if (!target || overlays.has(target)) return;
    const initialURL = provider();
    if (!initialURL) return;
    const layer = await ensureLayer();
    if (!target.isConnected || overlays.has(target)) return;
    const text = words();
    const overlay = document.createElement("div");
    overlay.className = `vbd-overlay vbd-theme-${theme()}`;
    const action = document.createElement("div");
    action.className = "vbd-action";
    const main = document.createElement("button");
    main.className = "vbd-main-button";
    main.type = "button";
    main.setAttribute("aria-label", kind === "image" ? text.image : text.video);
    main.innerHTML = `<span class="vbd-download-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 4v11m-4-4 4 4 4-4M5 20h14"/></svg></span><span class="vbd-button-label">${kind === "image" ? text.image : text.video}</span>`;
    main.addEventListener("click", (event) => {
      stop(event);
      void enqueue(provider() ?? initialURL, kind === "image" ? null : selectedHeight(), kind, main, target);
    });
    action.append(main);

    if (kind === "video") {
      const toggle = document.createElement("button");
      toggle.className = "vbd-menu-button";
      toggle.type = "button";
      toggle.setAttribute("aria-label", text.quality ?? translations.en.quality);
      toggle.title = text.quality ?? translations.en.quality;
      toggle.innerHTML = `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m7 9.5 5 5 5-5"/></svg>`;
      const menu = document.createElement("div");
      menu.className = "vbd-quality-menu";
      [[text.best, null], ["1080p", 1080], ["720p", 720], ["480p", 480]].forEach(([label, height]) => {
        const option = document.createElement("button");
        option.type = "button";
        option.textContent = label;
        if (height === selectedHeight()) option.classList.add("vbd-selected");
        option.addEventListener("click", (event) => {
          stop(event); menu.classList.remove("vbd-open");
          void enqueue(provider() ?? initialURL, height, "video", main, target);
        });
        menu.append(option);
      });
      const audio = document.createElement("button");
      audio.type = "button";
      audio.className = "vbd-audio-option";
      audio.textContent = `♫ ${text.audio}`;
      audio.addEventListener("click", (event) => {
        stop(event); menu.classList.remove("vbd-open");
        void enqueue(provider() ?? initialURL, null, "audio", main, target);
      });
      menu.append(audio);
      toggle.addEventListener("click", (event) => { stop(event); menu.classList.toggle("vbd-open"); schedulePosition(); });
      action.append(toggle);
      overlay.append(action, menu);
    } else {
      overlay.classList.add("vbd-image-overlay");
      overlay.append(action);
    }
    overlay.addEventListener("mousedown", stop, true);
    layer.append(overlay);
    overlays.set(target, { overlay, provider, kind });
    schedulePosition();
  }

  function createIntersection() { return new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      const candidate = candidates.get(entry.target);
      intersection.unobserve(entry.target);
      candidates.delete(entry.target);
      if (candidate && settings.enabled && settings.showOverlay) void createOverlay(entry.target, candidate.provider, candidate.kind);
    });
  }, { rootMargin: settings.scanRegion === "full" ? "0px" : "-30% 0px -30% 0px", threshold: 0.01 }); }
  let intersection = createIntersection();

  function queue(target, provider, kind = "video") {
    if (!target || overlays.has(target) || candidates.has(target) || !provider?.()) return;
    candidates.set(target, { provider, kind });
    intersection.observe(target);
  }

  function focusedState() {
    for (const adapter of adapters) {
      if (!adapter.matches?.() || !adapter.focus) continue;
      const state = adapter.focus(api);
      if (state?.active) return state;
    }
    return { active: false, target: null };
  }

  function related(target, focused) {
    return target === focused || target?.contains?.(focused) || focused?.contains?.(target);
  }

  function position() {
    positionFrame = null;
    const focus = focusedState();
    overlays.forEach((entry, target) => {
      if (!target.isConnected) {
        entry.overlay.remove(); overlays.delete(target); return;
      }
      const rect = target.getBoundingClientRect();
      const near = visible(target, 90, 60, 0) && inFocusBand(target);
      const allowed = !focus.active || related(target, focus.target);
      entry.overlay.hidden = !near || !allowed;
      if (!near || !allowed) return;
      const width = entry.overlay.offsetWidth || 80;
      const height = entry.overlay.offsetHeight || 30;
      const x = Math.max(8, Math.min(innerWidth - width - 8, rect.left + 9));
      const y = Math.max(8, Math.min(innerHeight - height - 8, rect.top + 9));
      entry.overlay.style.transform = `translate3d(${Math.round(x)}px,${Math.round(y)}px,0)`;
    });
    if (rootHost) rootHost.dataset.overlayCount = String(overlays.size);
  }

  function schedulePosition() {
    if (!positionFrame) positionFrame = requestAnimationFrame(position);
  }

  function scan() {
    schedulePosition();
    if (!pageEnabled || !settings.enabled || !settings.showOverlay) return;
    adapters.forEach((adapter) => {
      try { if (adapter.matches?.()) adapter.scan?.(api); } catch { /* One site must not affect another. */ }
    });
  }

  function reset() {
    intersection.disconnect();
    intersection = createIntersection();
    candidates = new WeakMap();
    overlays.forEach(({ overlay }) => overlay.remove());
    overlays.clear();
    schedulePosition();
  }

  function applySettings(next) {
    const merged = Settings.normalize(next);
    if (!Settings.isEqual(merged, settings)) {
      settings = merged; reset();
    }
    scan();
  }

  const api = {
    register(adapter) { if (!adapters.some((item) => item.id === adapter.id)) adapters.push(adapter); scan(); },
    queue,
    visible,
    largestVisible,
    linkAround,
    absoluteURL,
    normalizedKnownURL,
    hasOwnDownloadControl,
    schedulePosition,
    disable() { pageEnabled = false; reset(); rootHost?.remove(); rootHost = null; layerElement = null; },
  };
  globalThis.VideoBatchCore = api;

  new MutationObserver(() => {
    clearTimeout(scanTimer);
    scanTimer = setTimeout(scan, 650);
    schedulePosition();
  }).observe(document.documentElement, { childList: true, subtree: true });
  addEventListener("scroll", schedulePosition, { capture: true, passive: true });
  addEventListener("resize", schedulePosition, { passive: true });
  addEventListener("visibilitychange", () => { if (!document.hidden) scan(); });
  extensionAPI.storage.onChanged.addListener((changes, area) => {
    if (area !== "sync") return;
    const next = { ...settings };
    Object.entries(changes).forEach(([key, value]) => { next[key] = value.newValue; });
    applySettings(next);
  });
  extensionAPI.storage.sync.get(DEFAULTS).then(applySettings);
  setInterval(() => { if (!document.hidden) scan(); }, 5000);
})();
