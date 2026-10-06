(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  const matches = () => location.hostname === "youtube.com" || location.hostname.endsWith(".youtube.com");
  core.register({
    id: "youtube",
    matches,
    focus(api) {
      const active = /^\/(?:watch|shorts|live)(?:\/|$)/.test(location.pathname);
      return { active, target: active ? (document.querySelector("#movie_player") ?? api.largestVisible("video")) : null };
    },
    scan(api) {
      if (!/^\/(?:watch|shorts|live)(?:\/|$)/.test(location.pathname)) return;
      const active = api.normalizedKnownURL(location.href);
      const player = document.querySelector("#movie_player") ?? api.largestVisible("video");
      if (active && player) api.queue(player, () => api.normalizedKnownURL(location.href) ?? active, "video");
    },
  });
})();
