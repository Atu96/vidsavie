(() => {
  const DEFAULTS = Object.freeze({
    enabled: true,
    showOverlay: true,
    defaultQuality: "best",
    scanRegion: "middle",
    language: "en",
    theme: "auto",
  });
  const KEYS = Object.freeze(Object.keys(DEFAULTS));
  const THEMES = Object.freeze(new Set(["auto", "dark", "light"]));

  function normalize(value = {}) {
    return Object.fromEntries(KEYS.map((key) => {
      const candidate = value[key] ?? DEFAULTS[key];
      if (key === "theme" && !THEMES.has(candidate)) return [key, DEFAULTS.theme];
      if (key === "language" && !["auto", "en", "vi", "zh", "es", "fr", "de", "pt", "ja", "ko"].includes(candidate)) return [key, DEFAULTS.language];
      if (key === "scanRegion" && !["middle", "full"].includes(candidate)) return [key, DEFAULTS.scanRegion];
      return [key, candidate];
    }));
  }

  function changedValues(current = {}, next = {}) {
    const normalizedCurrent = normalize(current);
    const normalizedNext = normalize(next);
    return Object.fromEntries(KEYS
      .filter((key) => normalizedCurrent[key] !== normalizedNext[key])
      .map((key) => [key, normalizedNext[key]]));
  }

  function isEqual(left = {}, right = {}) {
    return Object.keys(changedValues(left, right)).length === 0;
  }

  const api = Object.freeze({ DEFAULTS, KEYS, THEMES, normalize, changedValues, isEqual });
  globalThis.VideoBatchSettings = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})();
