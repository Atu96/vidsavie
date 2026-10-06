(() => {
  const core = globalThis.VideoBatchCore;
  if (!core) return;
  function mediaURL(media) {
    const direct = core.absoluteURL(media.currentSrc || media.src || media.querySelector?.("source[src]")?.src);
    return direct ?? core.absoluteURL(location.href);
  }
  function imageURL(image) { return core.absoluteURL(image.currentSrc || image.src || image.dataset.src); }
  function imageCandidate(image) {
    const rect = image.getBoundingClientRect();
    if (!core.visible(image, 360, 220) || image.naturalWidth < 500 || image.naturalHeight < 280) return false;
    if (image.closest('header,nav,footer,[role="navigation"]')) return false;
    const hint = `${image.alt ?? ""} ${image.className ?? ""}`;
    return !/(avatar|profile|logo|icon|emoji|sprite)/i.test(hint) && rect.width * rect.height >= 90000;
  }
  core.register({
    id: "generic-site",
    matches: () => true,
    focus(api) {
      const dialog = [...document.querySelectorAll('[role="dialog"],:fullscreen')].find((node) => api.visible(node, 240, 160, 0) && node.querySelector("video,img"));
      if (!dialog) return { active: false, target: null };
      return { active: true, target: api.largestVisible("video", dialog) ?? api.largestVisible("img", dialog, imageCandidate) };
    },
    scan(api) {
      document.querySelectorAll("video").forEach((video) => {
        if (!api.visible(video, 200, 120) || api.hasOwnDownloadControl(video)) return;
        const initial = mediaURL(video);
        if (initial) api.queue(video, () => mediaURL(video) ?? initial, "video");
      });
      [...document.querySelectorAll("img")]
        .filter(imageCandidate)
        .sort((a, b) => {
          const ar = a.getBoundingClientRect(); const br = b.getBoundingClientRect();
          return (br.width * br.height) - (ar.width * ar.height);
        })
        .slice(0, 6)
        .forEach((image) => {
          if (api.hasOwnDownloadControl(image)) return;
          const initial = imageURL(image);
          if (initial) api.queue(image, () => imageURL(image) ?? initial, "image");
        });
    },
  });
})();
