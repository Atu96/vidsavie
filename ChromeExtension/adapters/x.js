(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  const matches = () => /(^|\.)(x|twitter)\.com$/.test(location.hostname);
  function imageURL(image) {
    try {
      const url = new URL(image.currentSrc || image.src, location.href);
      if (url.hostname !== "pbs.twimg.com" || !url.pathname.startsWith("/media/")) return null;
      url.searchParams.set("name", "orig");
      return url.href;
    } catch { return null; }
  }
  function targetForVideo(media) { return media.closest('[data-testid="videoPlayer"], [data-testid="videoComponent"]') ?? media; }
  core.register({
    id: "x",
    matches,
    focus(api) {
      const dialog = [...document.querySelectorAll('[role="dialog"]')].find((element) => api.visible(element, 200, 150, 0) && element.querySelector('video,img[src*="pbs.twimg.com/media/"]'));
      const photoMode = /\/status\/\d+\/photo\/\d+/.test(location.pathname);
      const scope = dialog ?? (photoMode ? document : null);
      if (!scope) return { active: false, target: null };
      const video = api.largestVisible("video", scope);
      const image = !video ? api.largestVisible('img[src*="pbs.twimg.com/media/"]', scope, imageURL) : null;
      return { active: true, target: video ? targetForVideo(video) : image };
    },
    scan(api) {
      document.querySelectorAll('article [data-testid="videoPlayer"],article [data-testid="videoComponent"],article [data-testid="playButton"]').forEach((media) => {
        const article = media.closest("article");
        const initial = api.normalizedKnownURL(article?.querySelector('a[href*="/status/"]')?.href ?? "");
        const target = targetForVideo(media);
        if (!initial || !api.visible(target, 100, 60)) return;
        api.queue(target, () => api.normalizedKnownURL(article?.querySelector('a[href*="/status/"]')?.href ?? "") ?? initial, "video");
      });
      document.querySelectorAll('article [data-testid="tweetPhoto"] img[src*="pbs.twimg.com/media/"]').forEach((image) => {
        const initial = imageURL(image);
        if (initial && api.visible(image, 100, 70)) api.queue(image, () => imageURL(image) ?? initial, "image");
      });
    },
  });
})();
