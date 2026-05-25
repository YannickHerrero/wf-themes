// wf-themes — Firefox extension background script
//
// Stage 2 (this commit): also re-inject on tab navigation, and properly remove
// the previous theme's CSS when switching. Theme is still hardcoded; native
// messaging arrives in the next commit.

const THEMES = ["paper", "stone", "sage", "clay", "ink"];

const URL_PATTERNS = [
  "*://discord.com/*",
  "*://claude.ai/*",
  "*://github.com/*",
  "*://*.reddit.com/*",
  "*://teams.microsoft.com/*",
  "*://mtools-rho.vercel.app/*",
];

const cssByTheme = {};
let currentTheme = null;

async function loadCss() {
  await Promise.all(
    THEMES.map(async (name) => {
      const url = browser.runtime.getURL(`themes/${name}.css`);
      const resp = await fetch(url);
      cssByTheme[name] = await resp.text();
    })
  );
}

async function insertInto(tabId, css) {
  try {
    await browser.tabs.insertCSS(tabId, {
      code: css,
      allFrames: true,
      cssOrigin: "user",
      runAt: "document_start",
    });
  } catch (err) {
    // Privileged pages (about:, file:) reject insertCSS — ignore.
  }
}

async function removeFrom(tabId, css) {
  try {
    await browser.tabs.removeCSS(tabId, {
      code: css,
      allFrames: true,
      cssOrigin: "user",
    });
  } catch (err) {
    // Tab may have closed or never had this CSS — ignore.
  }
}

async function applyTheme(name) {
  if (!cssByTheme[name]) {
    console.warn(`[wf-themes] unknown theme: ${name}`);
    return;
  }
  if (name === currentTheme) return;

  const prevCss = currentTheme ? cssByTheme[currentTheme] : null;
  const nextCss = cssByTheme[name];

  const tabs = await browser.tabs.query({ url: URL_PATTERNS });
  await Promise.all(
    tabs.map(async (t) => {
      if (prevCss) await removeFrom(t.id, prevCss);
      await insertInto(t.id, nextCss);
    })
  );
  currentTheme = name;
  console.log(`[wf-themes] applied ${name} to ${tabs.length} tab(s)`);
}

// Re-inject the current theme whenever a matching tab navigates: the page
// reload wipes out our injected CSS.
browser.tabs.onUpdated.addListener(
  (tabId, info) => {
    if (info.status !== "loading") return;
    if (!currentTheme) return;
    insertInto(tabId, cssByTheme[currentTheme]);
  },
  { urls: URL_PATTERNS, properties: ["status"] }
);

(async () => {
  await loadCss();
  await applyTheme("paper");
})();
