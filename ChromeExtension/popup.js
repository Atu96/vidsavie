const extensionAPI = globalThis.browser ?? globalThis.chrome;
const Settings = globalThis.VideoBatchSettings;
const DEFAULTS = Settings.DEFAULTS;
const I18n = globalThis.VideoBatchPopupI18n;
const controls = { enabled: document.querySelector("#enabled"), showOverlay: document.querySelector("#showOverlay"), defaultQuality: document.querySelector("#defaultQuality"), scanRegion: document.querySelector("#scanRegion"), language: document.querySelector("#language") };
const themeInputs = [...document.querySelectorAll('input[name="theme"]')];
const siteToggle = document.querySelector("#currentSiteEnabled");
const builtInHosts = /(^|\.)(youtube\.com|youtu\.be|douyin\.com|x\.com|twitter\.com|facebook\.com|instagram\.com)$|^www\.google\.(com|com\.vn)$/;
let settings = { ...DEFAULTS };
let appOnline = false;
let savedTimer;
let syncing = false;
let lastLocalEdit = 0;
let currentSite = null;
let localRevision = 0;
let pendingWrites = 0;
let writeQueue = Promise.resolve();

function send(message) {
  if (globalThis.browser) return extensionAPI.runtime.sendMessage(message);
  return new Promise((resolve, reject) => extensionAPI.runtime.sendMessage(message, (response) => {
    const error = extensionAPI.runtime.lastError;
    if (error) reject(new Error(error.message)); else resolve(response);
  }));
}
function queryTabs(query) {
  if (globalThis.browser) return extensionAPI.tabs.query(query);
  return new Promise((resolve) => extensionAPI.tabs.query(query, resolve));
}
function permissionRequest(origins) {
  if (globalThis.browser) return extensionAPI.permissions.request({ origins });
  return new Promise((resolve) => extensionAPI.permissions.request({ origins }, resolve));
}
function permissionRemove(origins) {
  if (globalThis.browser) return extensionAPI.permissions.remove({ origins });
  return new Promise((resolve) => extensionAPI.permissions.remove({ origins }, resolve));
}
function languageCode() {
  return I18n.resolveLanguage(settings.language, extensionAPI.i18n?.getUILanguage() ?? navigator.language);
}
function words() { return I18n.dictionaries[languageCode()]; }
function resolvedTheme() { return settings.theme === "auto" ? (matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark") : settings.theme; }
function translate() {
  const selected = words();
  document.documentElement.lang = languageCode();
  document.querySelectorAll("[data-i18n]").forEach((element) => { element.textContent = selected[element.dataset.i18n] ?? element.textContent; });
  document.querySelectorAll("[data-i18n-aria]").forEach((element) => element.setAttribute("aria-label", selected[element.dataset.i18nAria]));
}
function render() {
  Object.entries(controls).forEach(([key, control]) => { if (control.type === "checkbox") control.checked = Boolean(settings[key]); else control.value = settings[key]; });
  themeInputs.forEach((input) => { input.checked = input.value === settings.theme; });
  document.documentElement.dataset.theme = resolvedTheme();
  document.body.classList.toggle("disabled", !settings.enabled);
  const badge = document.querySelector("#connection");
  badge.className = `connection ${appOnline ? "online" : "offline"}`;
  badge.querySelector("b").dataset.i18n = appOnline ? "connected" : "offline";
  document.querySelector("#offline-card").hidden = appOnline;
  translate();
}
function showSaved() {
  const box = document.querySelector("#saved"); box.classList.add("visible"); clearTimeout(savedTimer);
  savedTimer = setTimeout(() => box.classList.remove("visible"), 1200);
}
async function postToApp(preferences = settings) {
  const response = await send({ type: "app.setPreferences", preferences });
  if (!response?.ok) throw new Error(response?.error ?? "offline");
  return response.data;
}
async function save(key, value) {
  if (settings[key] === value) return;
  settings = Settings.normalize({ ...settings, [key]: value });
  const revision = ++localRevision;
  const snapshot = { ...settings };
  pendingWrites++;
  lastLocalEdit = Date.now(); render(); showSaved();
  writeQueue = writeQueue.catch(() => {}).then(async () => {
  try {
    await extensionAPI.storage.sync.set({ [key]: value });
    const next = Settings.normalize(await postToApp(snapshot));
    if (revision !== localRevision) return;
    const changes = Settings.changedValues(settings, next);
    settings = next;
    if (Object.keys(changes).length > 0) await extensionAPI.storage.sync.set(changes);
    appOnline = true;
    await extensionAPI.storage.local.remove("pendingSync");
  }
  catch { if (revision === localRevision) { appOnline = false; await extensionAPI.storage.local.set({ pendingSync: true }); } }
  finally { pendingWrites--; render(); }
  });
  await writeQueue;
}
async function syncWithApp() {
  if (syncing || pendingWrites) return;
  syncing = true;
  const revision = localRevision;
  const started = Date.now();
  try {
    const response = await send({ type: "app.getPreferences" });
    if (!response?.ok) throw new Error("offline");
    const pending = (await extensionAPI.storage.local.get("pendingSync")).pendingSync;
    if (revision !== localRevision || pendingWrites) return;
    appOnline = true;
    if (pending) {
      const next = Settings.normalize(await postToApp());
      if (revision !== localRevision || pendingWrites) return;
      settings = next;
      await extensionAPI.storage.local.remove("pendingSync");
    } else if (started >= lastLocalEdit) {
      const next = Settings.normalize(response.data);
      const changes = Settings.changedValues(settings, next);
      settings = next;
      if (Object.keys(changes).length > 0) await extensionAPI.storage.sync.set(changes);
    }
  } catch { if (revision === localRevision) appOnline = false; }
  finally { syncing = false; render(); }
}
async function loadCurrentSite() {
  const [tab] = await queryTabs({ active: true, currentWindow: true });
  try {
    const url = new URL(tab?.url ?? "");
    if (!/^https?:$/.test(url.protocol) || builtInHosts.test(url.hostname)) return;
    currentSite = { origin: url.origin, pattern: `${url.origin}/*`, host: url.hostname, tabId: tab.id };
    document.querySelector("#site-card").hidden = false;
    document.querySelector("#site-name").textContent = url.hostname;
    const status = await send({ type: "generic.status", origin: url.origin });
    siteToggle.checked = Boolean(status?.enabled);
  } catch { /* Browser-internal pages cannot be enabled. */ }
}

controls.enabled.addEventListener("change", (event) => save("enabled", event.target.checked));
controls.showOverlay.addEventListener("change", (event) => save("showOverlay", event.target.checked));
controls.defaultQuality.addEventListener("change", (event) => save("defaultQuality", event.target.value));
controls.scanRegion.addEventListener("change", (event) => save("scanRegion", event.target.value));
controls.language.addEventListener("change", (event) => save("language", event.target.value));
themeInputs.forEach((input) => input.addEventListener("change", (event) => save("theme", event.target.value)));
siteToggle.addEventListener("change", async (event) => {
  if (!currentSite) return;
  const enabled = event.target.checked;
  event.target.disabled = true;
  try {
    if (enabled) {
      const granted = await permissionRequest([currentSite.pattern]);
      if (!granted) throw new Error("permission denied");
      const result = await send({ type: "generic.register", origin: currentSite.origin, tabId: currentSite.tabId });
      if (!result?.ok) throw new Error(result?.error);
    } else {
      await send({ type: "generic.unregister", origin: currentSite.origin, tabId: currentSite.tabId });
      await permissionRemove([currentSite.pattern]);
    }
    showSaved();
  } catch { event.target.checked = !enabled; }
  finally { event.target.disabled = false; }
});
document.querySelectorAll(".tab").forEach((tab) => tab.addEventListener("click", () => {
  document.querySelectorAll(".tab").forEach((item) => item.classList.toggle("active", item === tab));
  document.querySelectorAll(".panel").forEach((panel) => panel.classList.toggle("active", panel.dataset.panel === tab.dataset.tab));
}));
document.querySelector("#open-app").addEventListener("click", () => { extensionAPI.tabs.create({ url: "videobatch://open" }); setTimeout(syncWithApp, 1800); });
matchMedia("(prefers-color-scheme: light)").addEventListener("change", () => { if (settings.theme === "auto") render(); });
extensionAPI.storage.onChanged.addListener((changes, area) => {
  if (area !== "sync" || pendingWrites) return;
  const relevant = Object.fromEntries(Object.entries(changes).filter(([key]) => Settings.KEYS.includes(key)).map(([key, change]) => [key, change.newValue ?? DEFAULTS[key]]));
  if (!Object.keys(relevant).length) return;
  settings = Settings.normalize({ ...settings, ...relevant });
  localRevision++;
  render();
});
extensionAPI.storage.sync.get(DEFAULTS).then((stored) => {
  settings = Settings.normalize(stored);
  const version = extensionAPI.runtime.getManifest().version;
  document.querySelector("#version").textContent = version;
  document.querySelector("#footer-version").textContent = `v${version}`;
  render(); void loadCurrentSite(); void syncWithApp(); setInterval(syncWithApp, 15000);
});
