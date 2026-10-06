(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  const matches = () => location.hostname === "facebook.com" || location.hostname.endsWith(".facebook.com");
  function canonical(raw) {
    try {
      const url = new URL(raw, location.href);
      const reel = url.pathname.match(/^\/reel\/(\d+)/);
      const video = url.pathname.match(/^\/(?:watch\/)?videos\/(\d+)/);
      const story = url.searchParams.get("story_fbid") ?? url.searchParams.get("v");
      if (reel) return `https://www.facebook.com/reel/${reel[1]}`;
      if (video) return `https://www.facebook.com/watch/?v=${video[1]}`;
      if (story) return `https://www.facebook.com/watch/?v=${story}`;
      return /\/(?:reel|watch|videos|story\.php)/.test(url.pathname) ? url.href : null;
    } catch { return null; }
  }
  function videoURL(video) {
    const selector = 'a[href*="/reel/"],a[href*="/videos/"],a[href*="/watch"],a[href*="story_fbid="]';
    const article = video.closest('[role="article"], [role="dialog"]');
    // Never fall back to the feed URL: that made different videos on one
    // Facebook page share the same queue identity and look like duplicates.
    return canonical(article?.querySelector(selector)?.href ?? core.linkAround(video, selector) ?? canonical(location.href));
  }
  function imageURL(image) {
    try {
      const url = new URL(image.currentSrc || image.src, location.href);
      return url.hostname.endsWith("fbcdn.net") && /^https?:$/.test(url.protocol) ? url.href : null;
    } catch { return null; }
  }
  function isContentImage(image) {
    if (!imageURL(image) || !core.visible(image, 220, 150)) return false;
    if (image.closest('header,nav,[role="navigation"],[data-visualcompletion="ignore-dynamic"]')) return false;
    const article = image.closest('[role="article"]');
    // Feed images must belong to a real post with a permalink. This excludes
    // Marketplace cards, menus, suggestions, and most sponsored UI chrome.
    if (!article || !article.querySelector('a[href*="/posts/"],a[href*="story_fbid="],a[href*="/photo"],a[href*="/permalink/"]')) return false;
    if (image.closest('[role="complementary"],a[href*="/marketplace"],[aria-label*="Sponsored" i]')) return false;
    const alt = `${image.alt ?? ""} ${image.getAttribute("aria-label") ?? ""}`;
    return !/(profile picture|avatar|ảnh đại diện)/i.test(alt);
  }
  core.register({
    id: "facebook",
    matches,
    focus(api) {
      const dialog = [...document.querySelectorAll('[role="dialog"]')].find((node) => api.visible(node, 240, 180, 0) && node.querySelector('video,img[src*="fbcdn.net"]'));
      if (!dialog) return { active: false, target: null };
      const video = api.largestVisible("video", dialog);
      const image = !video ? api.largestVisible('img[src*="fbcdn.net"]', dialog, isContentImage) : null;
      return { active: true, target: video ?? image };
    },
    scan(api) {
      document.querySelectorAll("video").forEach((video) => {
        const initial = videoURL(video);
        const target = video.closest('[role="article"], [role="dialog"]')?.querySelector("video") ?? video;
        if (initial && api.visible(target, 180, 100)) api.queue(target, () => videoURL(video) ?? initial, "video");
      });
      document.querySelectorAll('[role="article"] img[src*="fbcdn.net"]').forEach((image) => {
        const initial = imageURL(image);
        if (initial && isContentImage(image)) api.queue(image, () => imageURL(image) ?? initial, "image");
      });
    },
  });
})();
