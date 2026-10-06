(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  const matches = () => /^www\.google\./.test(location.hostname) && location.pathname === "/search" && (new URLSearchParams(location.search).get("udm") === "2" || new URLSearchParams(location.search).get("tbm") === "isch");
  function usableImageURL(raw) {
    const candidate = core.absoluteURL(raw);
    if (!candidate) return null;
    // Branding and encrypted thumbnails are not the selected image. More
    // importantly, prefer the URL that Google has already rendered instead
    // of stale data-* values retained from an earlier result card.
    return /google\.(com|com\.vn)\/images\/branding|gstatic\.com\/images\/branding|encrypted-tbn\d*\.gstatic\.com/.test(candidate)
      ? null
      : candidate;
  }
  function originalURL(image) {
    const displayed = usableImageURL(image.currentSrc || image.src);
    if (displayed) return displayed;
    for (const attribute of ["data-iurl", "data-ou", "data-src", "src"]) {
      const candidate = usableImageURL(image.getAttribute(attribute));
      if (candidate) return candidate;
    }
    for (let node = image; node && node !== document.body; node = node.parentElement) {
      for (const anchor of node.querySelectorAll?.("a[href]") ?? []) {
        try {
          const url = new URL(anchor.href, location.href);
          for (const key of ["imgurl", "mediaurl", "url"]) {
            const candidate = usableImageURL(url.searchParams.get(key));
            if (candidate && !candidate.includes("google.com/search")) return candidate;
          }
        } catch { /* Ignore tracking links without a usable image URL. */ }
      }
      if (node.getAttribute?.("role") === "dialog") break;
    }
    return null;
  }
  function selectedImage(api) {
    if (!/(?:^|[&#])sv=/.test(location.hash)) return null;
    const candidates = [...document.querySelectorAll('img[src^="http"],img[data-src^="http"],img[data-iurl^="http"]')]
      .filter((image) => {
        const rect = image.getBoundingClientRect();
        const large = rect.width >= 360 && rect.height >= 220 && (image.naturalWidth >= 500 || image.naturalHeight >= 500);
        const external = Boolean(usableImageURL(image.currentSrc || image.src));
        return large && external && api.visible(image, 360, 220, 0) && originalURL(image);
      });
    return candidates.sort((a, b) => {
      const ar = a.getBoundingClientRect(); const br = b.getBoundingClientRect();
      return (br.width * br.height) - (ar.width * ar.height);
    })[0] ?? null;
  }
  core.register({
    id: "google-images",
    matches,
    focus(api) { const image = selectedImage(api); return { active: Boolean(image), target: image }; },
    scan(api) {
      const image = selectedImage(api);
      if (!image) return;
      const initial = originalURL(image);
      if (initial) api.queue(image, () => originalURL(image) ?? initial, "image");
    },
  });
})();
