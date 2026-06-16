// wf-themes — Firefox extension background script
//
// Connects to the wf-themes native messaging host, listens for theme change
// messages produced by the host as it watches ~/.config/wmenu/config.toml,
// and applies the matching bundled CSS to the 6 target sites.

const NATIVE_HOST = "com.yannick.wf_themes";
const STORAGE_KEY = "currentTheme";
const DEFAULT_THEME = "paper";

const THEMES = ["paper", "stone", "sage", "clay", "ink"];

const URL_PATTERNS = [
  "*://discord.com/*",
  "*://claude.ai/*",
  "*://github.com/*",
  "*://*.github.com/*",
  "*://viewscreen.githubusercontent.com/*",
  "*://*.reddit.com/*",
  "*://teams.microsoft.com/*",
  "*://teams.live.com/*",
  "*://outlook.office.com/*",
  "*://outlook.office365.com/*",
  "*://outlook.live.com/*",
  "*://outlook.com/*",
  "*://mail.proton.me/*",
  "*://mtools-rho.vercel.app/*",
  "http://localhost:5175/*",
];

// themesAsSections[theme] = [{ domains: [...], urlPrefixes: [...], code }, ...]
// One entry per `@-moz-document` block parsed out of the bundled .user.css.
// `code` is the bare inner CSS — the wrapper is discarded.
const themesAsSections = {};
let currentTheme = null;

let port = null;
let reconnectDelayMs = 1000;
const RECONNECT_MAX_MS = 30000;

// --- userstyle parser ------------------------------------------------------

// Walk balanced braces in CSS, skipping comments and quoted strings so
// `{` / `}` inside them don't throw off the depth count. Returns the index
// of the matching `}` (the char itself), or -1 if unbalanced.
function findBalancedClose(css, start) {
  let depth = 1;
  let i = start;
  while (i < css.length && depth > 0) {
    const ch = css[i];
    if (ch === "/" && css[i + 1] === "*") {
      const end = css.indexOf("*/", i + 2);
      if (end === -1) return -1;
      i = end + 2;
      continue;
    }
    if (ch === '"' || ch === "'") {
      const quote = ch;
      i++;
      while (i < css.length && css[i] !== quote) {
        if (css[i] === "\\") i++;
        i++;
      }
      i++;
      continue;
    }
    if (ch === "{") depth++;
    else if (ch === "}") depth--;
    i++;
  }
  return depth === 0 ? i - 1 : -1;
}

function parseMatchers(s) {
  const domains = [];
  const urlPrefixes = [];
  const re = /([a-zA-Z][-a-zA-Z]*)\(\s*"([^"]*)"\s*\)/g;
  let m;
  while ((m = re.exec(s)) !== null) {
    if (m[1] === "domain") domains.push(m[2]);
    else if (m[1] === "url-prefix") urlPrefixes.push(m[2]);
    // url() and regexp() forms are not used by the bundled themes — ignore.
  }
  return { domains, urlPrefixes };
}

function parseSections(css) {
  const sections = [];
  const headerRe = /@-moz-document\s+([^{]+)\{/g;
  let m;
  while ((m = headerRe.exec(css)) !== null) {
    const bodyStart = headerRe.lastIndex;
    const closeIdx = findBalancedClose(css, bodyStart);
    if (closeIdx === -1) {
      console.warn("[wf-themes] unbalanced @-moz-document block, skipping");
      break;
    }
    sections.push({
      ...parseMatchers(m[1]),
      code: css.slice(bodyStart, closeIdx),
    });
    headerRe.lastIndex = closeIdx + 1;
  }
  return sections;
}

// --- loading ---------------------------------------------------------------

async function loadCss() {
  await Promise.all(
    THEMES.map(async (name) => {
      const url = browser.runtime.getURL(`themes/${name}.css`);
      const resp = await fetch(url);
      themesAsSections[name] = parseSections(await resp.text());
      console.log(
        `[wf-themes] parsed ${name}: ${themesAsSections[name].length} section(s)`
      );
    })
  );
}

// `domain(d)` in @-moz-document matches when the document's host equals d or
// is a subdomain of d — same rule as Mozilla's implementation.
function hostMatchesDomain(host, domain) {
  return host === domain || host.endsWith("." + domain);
}

// Pick the section(s) of `theme` that apply to `url` and return their bare
// CSS concatenated. Match per-tab in JS so we don't have to rely on the
// browser honouring @-moz-document in injected stylesheets.
function cssForTabUrl(theme, url) {
  const sections = themesAsSections[theme];
  if (!sections || !url) return null;
  let host;
  try {
    host = new URL(url).hostname;
  } catch {
    return null;
  }
  const parts = [];
  for (const s of sections) {
    const domainHit = s.domains.some((d) => hostMatchesDomain(host, d));
    const prefixHit = s.urlPrefixes.some((p) => url.startsWith(p));
    if (domainHit || prefixHit) parts.push(s.code);
  }
  return parts.length ? parts.join("\n") : null;
}

async function insertInto(tabId, css) {
  try {
    await browser.tabs.insertCSS(tabId, {
      code: css,
      allFrames: true,
      runAt: "document_start",
    });
  } catch (err) {
    // Privileged pages reject insertCSS — ignore.
  }
}

async function removeFrom(tabId, css) {
  try {
    await browser.tabs.removeCSS(tabId, {
      code: css,
      allFrames: true,
    });
  } catch (err) {
    // Tab may have closed or never had this CSS — ignore.
  }
}

// Serialize theme applications. Without this, two messages arriving in quick
// succession both read `currentTheme` before either updates it, so neither
// removes what the other just inserted — the tab ends up with two themes
// layered on top of each other.
let applyChain = Promise.resolve();

function applyTheme(name) {
  applyChain = applyChain
    .then(() => doApplyTheme(name))
    .catch((err) => console.error(`[wf-themes] applyTheme failed:`, err));
  return applyChain;
}

async function doApplyTheme(name) {
  if (!themesAsSections[name]) {
    console.warn(`[wf-themes] unknown theme: ${name}`);
    return;
  }
  if (name === currentTheme) return;

  const prevTheme = currentTheme;
  currentTheme = name;
  await browser.storage.local.set({ [STORAGE_KEY]: name });

  const tabs = await browser.tabs.query({ url: URL_PATTERNS });
  await Promise.all(
    tabs.map(async (t) => {
      const prevCss = prevTheme ? cssForTabUrl(prevTheme, t.url) : null;
      const nextCss = cssForTabUrl(name, t.url);
      if (prevCss) await removeFrom(t.id, prevCss);
      if (nextCss) await insertInto(t.id, nextCss);
    })
  );
  console.log(`[wf-themes] applied ${name} to ${tabs.length} tab(s)`);
}

browser.runtime.onMessage.addListener((msg) => {
  if (msg && msg.type === "setTheme" && typeof msg.theme === "string") {
    applyTheme(msg.theme);
  }
});

browser.tabs.onUpdated.addListener(
  (tabId, info, tab) => {
    if (info.status !== "loading") return;
    if (!currentTheme) return;
    const css = cssForTabUrl(currentTheme, tab.url);
    if (css) insertInto(tabId, css);
  },
  { urls: URL_PATTERNS, properties: ["status"] }
);

function connectNativeHost() {
  try {
    port = browser.runtime.connectNative(NATIVE_HOST);
  } catch (err) {
    console.error(`[wf-themes] connectNative threw:`, err);
    scheduleReconnect();
    return;
  }

  port.onMessage.addListener((msg) => {
    if (!msg || typeof msg.theme !== "string") {
      console.warn(`[wf-themes] ignoring malformed message:`, msg);
      return;
    }
    reconnectDelayMs = 1000; // healthy traffic → reset backoff
    applyTheme(msg.theme);
  });

  port.onDisconnect.addListener(() => {
    const err = browser.runtime.lastError || port.error;
    console.warn(`[wf-themes] native host disconnected:`, err);
    port = null;
    scheduleReconnect();
  });

  console.log(`[wf-themes] connected to native host ${NATIVE_HOST}`);
}

function scheduleReconnect() {
  setTimeout(() => {
    connectNativeHost();
  }, reconnectDelayMs);
  reconnectDelayMs = Math.min(reconnectDelayMs * 2, RECONNECT_MAX_MS);
}

(async () => {
  await loadCss();

  // Apply the last-known theme immediately so tabs are themed before the
  // native host has a chance to respond. The host will overwrite this with
  // the authoritative current value as soon as it connects.
  const stored = await browser.storage.local.get(STORAGE_KEY);
  await applyTheme(stored[STORAGE_KEY] || DEFAULT_THEME);

  connectNativeHost();
})();
