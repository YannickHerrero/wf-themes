// wf-themes — Firefox extension background script
//
// Stage 1 (this commit): load the 5 bundled theme CSS files into memory and
// inject a hardcoded default (paper) into matching tabs at startup. No native
// messaging yet — that arrives in later commits.

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

async function applyToTab(tabId, css) {
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

async function applyTheme(name) {
  const css = cssByTheme[name];
  if (!css) {
    console.warn(`[wf-themes] unknown theme: ${name}`);
    return;
  }
  currentTheme = name;
  const tabs = await browser.tabs.query({ url: URL_PATTERNS });
  await Promise.all(tabs.map((t) => applyToTab(t.id, css)));
  console.log(`[wf-themes] applied ${name} to ${tabs.length} tab(s)`);
}

(async () => {
  await loadCss();
  await applyTheme("paper");
})();
