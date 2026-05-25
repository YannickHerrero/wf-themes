# wf-themes

Firefox extension that themes a fixed set of websites and reacts in real time
to the active theme published by [wmenu](https://github.com/YannickHerrero/wmenu).

Pick a theme in wmenu → matching CSS is applied across all open tabs within a
few hundred milliseconds. No clicks, no Stylus, no page reload (beyond the
normal one when a new tab is opened).

## How it works

```
   ┌──────────┐    config.toml      ┌──────────────────┐   stdio (JSON)   ┌────────────┐
   │  wmenu   │ ──── writes ───────▶│ wf-themes-host   │ ───── pushes ───▶│ Firefox    │
   │  (Rust)  │   ~/.config/wmenu/  │ (Rust, watches)  │     {theme:"x"}  │ extension  │
   └──────────┘                     └──────────────────┘                  └────────────┘
                                                                                 │
                                                                          insertCSS()
                                                                                 ▼
                                                                         themed tabs
```

- **wmenu** persists its current theme to `~/.config/wmenu/config.toml`
  (key `theme`, lowercase: `paper|stone|sage|clay|ink`).
- **wf-themes-host** is a small Rust binary that Firefox spawns as a "native
  messaging host". It watches that config file with `notify`, and pushes
  `{"theme": "..."}` over stdio every time the value changes.
- **The extension** receives messages and uses `browser.tabs.insertCSS` to
  apply the matching bundled stylesheet to every open tab on the 6 target
  sites: Discord, Claude, GitHub, Reddit, Microsoft Teams, MTools.

The theme CSS itself lives in `extension/themes/{paper,stone,sage,clay,ink}.css`,
copied verbatim from the [stylus](https://github.com/YannickHerrero/user-styles)
repo (`styles/all/*.user.css`). The two repos are intentionally independent —
re-run `scripts/sync-themes.sh` after a stylus change.

## Install

Prerequisites: `cargo`, `zip`, and Firefox.

```bash
git clone https://github.com/YannickHerrero/wf-themes.git
cd wf-themes

# 1. Build and install the native messaging host.
bash scripts/install-native-host.sh
# → installs ~/.local/bin/wf-themes-host
# → writes  ~/.mozilla/native-messaging-hosts/com.yannick.wf_themes.json

# 2. Build the .xpi (unsigned). For Firefox Release, this needs to be signed
#    by Mozilla before it can be installed permanently — see below.
bash scripts/build-xpi.sh
# → produces dist/wf-themes.xpi
```

### Signing the extension (Firefox Release)

Firefox Release refuses to install unsigned extensions. Self-distributed
("unlisted") signing through AMO is free and takes a few minutes:

```bash
# One-time: install web-ext and grab API credentials from
#   https://addons.mozilla.org/developers/addon/api/key/
npm install -g web-ext

web-ext sign \
  --source-dir extension \
  --channel unlisted \
  --api-key="${AMO_API_KEY}" \
  --api-secret="${AMO_API_SECRET}"
# → writes a signed .xpi to web-ext-artifacts/
```

Install the signed `.xpi` via `about:addons` → ⚙ → **Install Add-on From File**,
or drag and drop into Firefox.

### Quick test without signing (about:debugging)

Useful for development; the extension is unloaded on browser restart.

1. `about:debugging#/runtime/this-firefox` → **Load Temporary Add-on**
2. Pick `extension/manifest.json`
3. Click the extension's **Inspect** button to open the background console

## Verifying end-to-end

1. Open a tab on one of the 6 themed sites (Discord, Claude, etc.).
2. In a terminal, edit `~/.config/wmenu/config.toml` and change `theme = "paper"`
   to `theme = "ink"`. Save.
3. The browser should re-theme within ~200ms. Open a fresh tab on the same
   site — already themed.
4. Switch back via the wmenu UI; same result.

## Re-syncing themes from stylus

If a theme palette changes in the [stylus](https://github.com/YannickHerrero/user-styles) repo:

```bash
bash scripts/sync-themes.sh         # defaults to ~/dev/stylus
bash scripts/build-xpi.sh           # rebuild the .xpi
# re-sign and reinstall
```

## Troubleshooting

- **Extension installs but nothing themes** — open the background console
  (`about:debugging` → Inspect). Look for `connected to native host` and
  `applied <theme>`. If you see `native host disconnected`, the binary path
  in `~/.mozilla/native-messaging-hosts/com.yannick.wf_themes.json` is wrong
  or the binary isn't executable — re-run `install-native-host.sh`.
- **Native host stderr** — Firefox suppresses native host stderr by default.
  To see it, launch Firefox from a terminal; the host's `eprintln!` lines
  show up in that terminal.
- **Manual host smoke test:**
  ```bash
  printf '\x00\x00\x00\x00' | ~/.local/bin/wf-themes-host
  # → should print a length-prefixed JSON {"theme":"<current>"} and exit
  ```
- **Theme not changing on save** — confirm wmenu actually wrote the file:
  `cat ~/.config/wmenu/config.toml | grep theme`. Some editors save via
  rename which can briefly remove and re-add the file; the host watches the
  parent dir to survive this, but unusual save patterns may need adjustment.

## Layout

```
wf-themes/
├── extension/
│   ├── manifest.json
│   ├── background.js
│   └── themes/
│       ├── paper.css   stone.css   sage.css   clay.css   ink.css
├── native-host/
│   ├── Cargo.toml
│   └── src/main.rs
├── packaging/
│   └── com.yannick.wf_themes.json.tpl
└── scripts/
    ├── install-native-host.sh
    ├── build-xpi.sh
    └── sync-themes.sh
```

## License

MIT
