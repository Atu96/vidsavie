(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  const matches = () => location.hostname === "douyin.com" || location.hostname.endsWith(".douyin.com");

  function attributeVideoURL(api, video) {
    for (let node = video, depth = 0; node && depth < 14; node = node.parentElement, depth += 1) {
      for (const attribute of node.attributes ?? []) {
        const normalized = api.normalizedKnownURL(attribute.value, location.href);
        if (normalized) return normalized;
        const videoID = attribute.value?.match(/(?:\/video\/|(?:aweme|modal)[_-]?id[^\d]*)(\d{12,})/i)?.[1];
        if (videoID) return `https://www.douyin.com/video/${videoID}`;
      }
    }
    return null;
  }

  function videoURL(api, video) {
    return api.normalizedKnownURL(location.href)
      ?? api.normalizedKnownURL(api.linkAround(video, 'a[href*="/video/"]', 16), location.href)
      ?? attributeVideoURL(api, video);
  }

  function activeVideo(api) {
    return api.largestVisible("video", document, (video) => Boolean(videoURL(api, video)));
  }

  core.register({
    id: "douyin",
    matches,
    focus(api) {
      const video = activeVideo(api);
      return { active: Boolean(video), target: video };
    },
    scan(api) {
      const video = activeVideo(api);
      const active = video && videoURL(api, video);
      if (video && active) api.queue(video, () => videoURL(api, video) ?? active, "video");
    },
  });
})();
