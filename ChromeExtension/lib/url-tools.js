(() => {
  function absoluteURL(raw, base = globalThis.location?.href) {
    try {
      const url = new URL(raw, base);
      return /^https?:$/.test(url.protocol) ? url.href : null;
    } catch { return null; }
  }

  function normalizedKnownURL(raw, base = globalThis.location?.href) {
    try {
      const url = new URL(raw, base);
      const host = url.hostname.toLowerCase();
      if (host === "youtu.be") {
        const id = url.pathname.split("/").filter(Boolean)[0];
        return id ? `https://www.youtube.com/watch?v=${id}` : null;
      }
      if (host === "youtube.com" || host.endsWith(".youtube.com")) {
        const id = url.searchParams.get("v") ?? url.pathname.match(/^\/(?:shorts|live)\/([^/?]+)/)?.[1];
        return id ? `https://www.youtube.com/watch?v=${id}` : null;
      }
      if (host === "douyin.com" || host.endsWith(".douyin.com")) {
        const id = url.searchParams.get("modal_id") ?? url.searchParams.get("modalId") ?? url.pathname.match(/\/video\/(\d+)/)?.[1];
        return id ? `https://www.douyin.com/video/${id}` : null;
      }
      if (host === "x.com" || host.endsWith(".x.com") || host === "twitter.com" || host.endsWith(".twitter.com")) {
        const id = url.pathname.match(/\/status\/(\d+)/)?.[1];
        return id ? `https://x.com/i/status/${id}` : null;
      }
      if (host === "instagram.com" || host.endsWith(".instagram.com")) {
        const segments = url.pathname.split("/").filter(Boolean);
        const typeIndex = segments.findIndex((segment) => ["p", "reel", "reels", "tv", "stories"].includes(segment));
        if (typeIndex < 0) return null;
        const type = segments[typeIndex];
        if (type === "stories") {
          const owner = segments[typeIndex + 1];
          const storyID = segments[typeIndex + 2];
          if (!owner) return null;
          return storyID
            ? `https://www.instagram.com/stories/${owner}/${storyID}/`
            : `https://www.instagram.com/stories/${owner}/`;
        }
        const mediaID = segments[typeIndex + 1];
        if (!mediaID) return null;
        const normalizedType = type === "reels" ? "reel" : type;
        return `https://www.instagram.com/${normalizedType}/${mediaID}/`;
      }
      if (host === "b23.tv" || host.endsWith(".b23.tv")) {
        const shortID = url.pathname.split("/").filter(Boolean)[0];
        return shortID ? `https://b23.tv/${shortID}` : null;
      }
      if (host === "bilibili.com" || host.endsWith(".bilibili.com")) {
        const videoID = url.pathname.match(/\/video\/((?:BV[\w]+)|(?:av\d+))/i)?.[1];
        if (videoID) {
          const part = url.searchParams.get("p");
          return `https://www.bilibili.com/video/${videoID}${part && /^\d+$/.test(part) ? `?p=${part}` : ""}`;
        }
        const playPath = url.pathname.match(/\/(bangumi|cheese)\/play\/((?:ep|ss)\d+)/i);
        if (playPath) return `https://www.bilibili.com/${playPath[1].toLowerCase()}/play/${playPath[2]}`;
        if (host === "live.bilibili.com") {
          const roomID = url.pathname.match(/^\/(\d+)/)?.[1];
          return roomID ? `https://live.bilibili.com/${roomID}` : null;
        }
      }
    } catch { /* Dynamic links can be temporarily incomplete. */ }
    return null;
  }

  function genericSite(raw) {
    try {
      const url = new URL(raw);
      if (!/^https?:$/.test(url.protocol) || !url.hostname) return null;
      const origin = url.origin;
      const hash = [...origin].reduce(
        (value, character) => ((value * 31) + character.charCodeAt(0)) >>> 0,
        7
      ).toString(36);
      return { origin, pattern: `${origin}/*`, id: `vbd-generic-${hash}` };
    } catch { return null; }
  }

  const api = Object.freeze({ absoluteURL, normalizedKnownURL, genericSite });
  globalThis.VideoBatchURLTools = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})();
