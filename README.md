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

Prerequisites: `cargo`, `python3`, and Firefox.

### Linux Firefox

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

### Windows Firefox with WSL-resident wmenu

If Firefox runs on Windows but wmenu is in WSL, the Linux ELF host needs a
thin Windows wrapper so Firefox can launch it across the boundary. Two steps:

**Inside WSL** (same as Linux install — builds the actual binary):

```bash
git clone https://github.com/YannickHerrero/wf-themes.git
cd wf-themes
bash scripts/install-native-host.sh
# → installs /home/<wsl-user>/.local/bin/wf-themes-host
```

The Linux-side native messaging manifest written to `~/.mozilla/...` is
harmless but inert — Windows Firefox doesn't read it. The Windows registry
entry below is what actually wires things up.

**In Windows PowerShell** (registers the wrapper + the registry entry that
Windows Firefox reads):

```powershell
cd \\wsl.localhost\<your-distro>\home\<wsl-user>\dev\wf-themes
.\windows\install.ps1
# → writes %LOCALAPPDATA%\wf-themes\wf-themes-host.bat
# → writes %LOCALAPPDATA%\wf-themes\com.yannick.wf_themes.json
# → creates HKCU\Software\Mozilla\NativeMessagingHosts\com.yannick.wf_themes
```

The .bat wraps `wsl.exe -e /home/<user>/.local/bin/wf-themes-host` and
preserves binary stdio so Firefox's length-prefixed JSON wire format
survives the WSL ↔ Windows hop. Override the binary path with
`.\windows\install.ps1 -BinPath "/some/other/path"` if you keep the host
somewhere non-default.

Restart Firefox (or disable + re-enable the extension) afterwards to force
a reconnect.

**Build the .xpi** (works equally well from WSL or Windows — Mozilla signs
the same archive either way):

```bash
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

- **Extension installs and themes a fallback (paper) but never reacts to wmenu changes** —
  the extension is loaded but the native host isn't connecting. Open the
  background console (`about:debugging` → Inspect): if you don't see
  `connected to native host`, the host lookup failed.
  - **Linux Firefox**: check the manifest path and binary executable bit:
    `cat ~/.mozilla/native-messaging-hosts/com.yannick.wf_themes.json` and
    `ls -l ~/.local/bin/wf-themes-host`. Re-run `bash scripts/install-native-host.sh`.
  - **Windows Firefox**: check the registry entry exists:
    `reg query "HKCU\Software\Mozilla\NativeMessagingHosts\com.yannick.wf_themes"` —
    its default value must point at an existing `com.yannick.wf_themes.json`.
    Re-run `windows\install.ps1` from PowerShell.
- **Extension ID drifted** — in the background console run `browser.runtime.id`.
  Must match the `allowed_extensions` entry in the manifest
  (`wf-themes@yannick.herrero`). If different, the signed extension ID changed
  — update both manifest templates and re-run the installers.
- **Native host stderr** — Firefox suppresses native host stderr by default.
  To see it, launch Firefox from a terminal; the host's `eprintln!` lines
  show up there.
- **Manual host smoke test** (Linux/WSL):
  ```bash
  printf '\x00\x00\x00\x00' | ~/.local/bin/wf-themes-host
  # → prints a length-prefixed JSON {"theme":"<current>"} then exits on EOF
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
│   └── com.yannick.wf_themes.json.tpl   (Linux NM manifest template)
├── windows/                              (Windows-side bridge)
│   ├── wf-themes-host.bat.tpl
│   ├── com.yannick.wf_themes.json.tpl
│   └── install.ps1
└── scripts/
    ├── install-native-host.sh           (run inside WSL/Linux)
    ├── build-xpi.sh
    └── sync-themes.sh
```

## License

MIT
