---
name: add-website
description: Add a new wf-themes supported website from a URL and optional HTML source by creating a versioned custom-sites/<site>.css file using the repo's watched-folder custom site format. Use when the user says /skill:add-website, add website, add supported site, or wants a new custom site theme.
---

# Add Website

This project-level skill adds a new supported website to `wf-themes` without
changing the bundled extension code. It creates or updates a versioned custom
site stylesheet under `custom-sites/`, following `docs/custom-sites.md`.

The user may invoke it like:

```text
/skill:add-website https://example.com '<html source here>'
```

or:

```text
/skill:add-website https://example.com path/to/source.html
```

If the HTML source is large or omitted, ask the user for the page source or make
a conservative scaffold that can be refined later.

## Required workflow

1. Read these project files first:
   - `docs/custom-sites.md`
   - `custom-sites/example.css`
   - any existing `custom-sites/*.css` for naming/style conventions
2. Parse the target URL:
   - Prefer `domain("host")` for a whole site.
   - Prefer `url-prefix("https://host/path")` only when the style must be limited
     to one app/subpath.
   - Strip a leading `www.` from the filename slug unless it is meaningful.
3. Choose the output file:
   - Use `custom-sites/<slug>.css`, e.g. `custom-sites/linear.css`.
   - If it exists, update it instead of creating a duplicate.
4. Generate one file containing all five themes:
   - `paper`
   - `stone`
   - `sage`
   - `clay`
   - `ink`
5. Each theme block must use this structure:

   ```css
   @wf-theme paper {
     @-moz-document domain("example.com") {
       /* CSS */
     }
   }
   ```

6. Use the current palette values unless the user explicitly provides different
   colors:

   ```text
   paper background: #E5D8C0, foreground: #151515
   stone background: #D3D7DB, foreground: #151515
   sage  background: #CCD4BE, foreground: #151515
   clay  background: #D9C0A8, foreground: #151515
   ink   background: #151515, foreground: #E5D8C0
   ```

7. When HTML is available, inspect it for stable selectors:
   - Prefer semantic elements and app-level containers.
   - Prefer readable class names that look stable.
   - Avoid generated/hash-like classes unless there is no alternative.
   - Keep CSS conservative: base background, text color, surfaces/cards,
     inputs/buttons, links, borders, and obvious nav/sidebar containers.
   - Do not invent complex site-specific behavior.
8. When HTML is unavailable, create a conservative scaffold with obvious generic
   selectors and TODO comments.
9. Do not edit `extension/themes/*.css` for custom websites.
10. Do not rebuild or re-sign the extension for a custom website-only change.
11. Install the custom site file into the Windows watched runtime folder used
    by Zen/Firefox on Windows. This is required for this user's setup.

    From WSL/Linux, use `wslpath` so the command works even if the distro or
    repo path changes:

    ```bash
    WIN_SRC="$(wslpath -w custom-sites/<slug>.css)"
    powershell.exe -NoProfile -Command "
      New-Item -ItemType Directory -Force \"\$env:APPDATA\\wf-themes\\config\\sites\" | Out-Null
      Copy-Item \"${WIN_SRC}\" \"\$env:APPDATA\\wf-themes\\config\\sites\\<slug>.css\" -Force
    "
    ```

    If operating directly in Windows PowerShell instead of WSL, use:

    ```powershell
    New-Item -ItemType Directory -Force "$env:APPDATA\wf-themes\config\sites" | Out-Null
    Copy-Item .\custom-sites\<slug>.css "$env:APPDATA\wf-themes\config\sites\<slug>.css" -Force
    ```

12. Run `git diff --check` after editing.
13. Commit the change as one atomic commit:

    ```bash
    git add custom-sites/<slug>.css
    git commit -m "style: add <site> custom theme"
    ```

## Final response

Summarize:

- created/updated file path
- matcher used (`domain(...)` or `url-prefix(...)`)
- confirm it was copied to the Windows watched runtime folder (`%APPDATA%\wf-themes\config\sites\`)
- commit hash
- any selectors/TODOs that need manual verification
