(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;

  const matches = () => /(^|\.)(bilibili\.com|b23\.tv)$/.test(location.hostname);
  const playerSelectors = [
    ".bpx-player-container",
    "#bilibili-player",
    ".bilibili-player",
    ".squirtle-video-wrap",
  ];

  function pageURL() {
    return core.normalizedKnownURL(location.href);
  }

  function activeVideo(api) {
    for (const selector of playerSelectors) {
      const player = document.querySelector(selector);
      if (!player) continue;
      const video = api.largestVisible("video", player);
      if (video) return video;
    }
    return api.largestVisible("video");
  }

  core.register({
    id: "bilibili",
    matches,
    focus(api) {
      const url = pageURL();
      const target = url ? activeVideo(api) : null;
      return { active: Boolean(url && target), target };
    },
    scan(api) {
      const initial = pageURL();
      if (!initial) return;
      const video = activeVideo(api);
      if (video) api.queue(video, () => pageURL() ?? initial, "video");
    },
  });
})();
