(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  const matches = () => location.hostname === "instagram.com" || location.hostname.endsWith(".instagram.com");
  const mediaLinkSelector = [
    'a[href*="/p/"]',
    'a[href*="/reel/"]',
    'a[href*="/reels/"]',
    'a[href*="/tv/"]',
    'a[href*="/stories/"]',
  ].join(",");

  function videoURL(media) {
    const nearby = core.linkAround(media, mediaLinkSelector);
    return core.normalizedKnownURL(nearby) ?? core.normalizedKnownURL(location.href);
  }

  function focusedVideo(api) {
    const pageURL = core.normalizedKnownURL(location.href);
    if (!pageURL) return null;
    return api.largestVisible("video", document, (video) => Boolean(videoURL(video)));
  }
  function imageURL(image) {
    try {
      const url = new URL(image.currentSrc || image.src, location.href);
      return (url.hostname.endsWith("cdninstagram.com") || url.hostname.endsWith("fbcdn.net")) && /^https?:$/.test(url.protocol) ? url.href : null;
    } catch { return null; }
  }
  function isContentImage(image) {
    if (!imageURL(image) || !core.visible(image, 220, 150)) return false;
    if (image.closest("header,nav") || !image.closest('article,[role="dialog"]')) return false;
    const alt = `${image.alt ?? ""} ${image.getAttribute("aria-label") ?? ""}`;
    return !/(profile picture|avatar|ảnh đại diện)/i.test(alt);
  }
  core.register({
    id: "instagram",
    matches,
    focus(api) {
      const pageVideo = focusedVideo(api);
      if (pageVideo) return { active: true, target: pageVideo };
      const dialog = [...document.querySelectorAll('[role="dialog"]')].find((node) => api.visible(node, 240, 180, 0) && node.querySelector("video,img"));
      if (!dialog) return { active: false, target: null };
      const target = api.largestVisible("video", dialog, (video) => Boolean(videoURL(video)))
        ?? api.largestVisible("img", dialog, isContentImage);
      return { active: Boolean(target), target: target ?? null };
    },
    scan(api) {
      const pageVideo = focusedVideo(api);
      if (pageVideo) {
        const initial = videoURL(pageVideo);
        if (initial) api.queue(pageVideo, () => videoURL(pageVideo) ?? initial, "video");
      } else {
        document.querySelectorAll("article video,[role=dialog] video").forEach((video) => {
          const initial = videoURL(video);
          if (initial && api.visible(video, 180, 100)) api.queue(video, () => videoURL(video) ?? initial, "video");
        });
      }
      document.querySelectorAll('article img,[role="dialog"] img').forEach((image) => {
        const initial = imageURL(image);
        if (initial && isContentImage(image)) api.queue(image, () => imageURL(image) ?? initial, "image");
      });
    },
  });
})();
