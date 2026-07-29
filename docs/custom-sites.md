# Adding a custom supported website

This extension can load extra website styles from a native-host watched folder.
After the `0.2.0` extension and matching native host are installed once, adding
or editing a supported website only requires changing a CSS file; you do not
need to rebuild, re-sign, or reinstall the XPI.

## Paths

Keep custom site styles in this repo so they are versioned:

```text
custom-sites/<site-name>.css
```

Then copy or symlink the file into the runtime watched folder:

```text
Linux:   ~/.config/wf-themes/sites/
Windows: %APPDATA%\wf-themes\config\sites\
```

On Windows, `%APPDATA%` usually expands to:

```text
C:\Users\<you>\AppData\Roaming
```

## CSS file format

Use one file per website. Put all wf-themes themes for that website in the same
file.

Supported theme names:

```text
paper, stone, sage, clay, ink
```

Supported matchers:

```css
@-moz-document domain("example.com") { ... }
@-moz-document url-prefix("https://example.com/app") { ... }
```

Template:

```css
@wf-theme paper {
  @-moz-document domain("example.com") {
    /* paper CSS here */
  }
}

@wf-theme stone {
  @-moz-document domain("example.com") {
    /* stone CSS here */
  }
}

@wf-theme sage {
  @-moz-document domain("example.com") {
    /* sage CSS here */
  }
}

@wf-theme clay {
  @-moz-document domain("example.com") {
    /* clay CSS here */
  }
}

@wf-theme ink {
  @-moz-document domain("example.com") {
    /* ink CSS here */
  }
}
```

## Exact procedure: Windows / Zen or Firefox

From the repo root in PowerShell:

```powershell
# 1. Create a new versioned style file in this repo.
Copy-Item .\custom-sites\example.css .\custom-sites\my-site.css

# 2. Edit custom-sites\my-site.css.
#    Replace example.com with the target domain and replace the CSS in each
#    @wf-theme block.
notepad .\custom-sites\my-site.css

# 3. Ensure the watched runtime folder exists.
New-Item -ItemType Directory -Force "$env:APPDATA\wf-themes\config\sites"

# 4. Copy the style file into the watched folder.
Copy-Item .\custom-sites\my-site.css "$env:APPDATA\wf-themes\config\sites\my-site.css" -Force
```

The native host should detect the new or changed file automatically. Open or
reload the website, then switch themes in wmenu to verify every theme block.

## Exact procedure: Linux / Firefox

From the repo root:

```bash
# 1. Create a new versioned style file in this repo.
cp custom-sites/example.css custom-sites/my-site.css

# 2. Edit custom-sites/my-site.css.
#    Replace example.com with the target domain and replace the CSS in each
#    @wf-theme block.
$EDITOR custom-sites/my-site.css

# 3. Ensure the watched runtime folder exists.
mkdir -p ~/.config/wf-themes/sites

# 4. Copy the style file into the watched folder.
cp custom-sites/my-site.css ~/.config/wf-themes/sites/my-site.css
```

The native host should detect the new or changed file automatically. Open or
reload the website, then switch themes in wmenu to verify every theme block.

## Optional: symlink instead of copying

If you want edits in `custom-sites/` to apply immediately without manually
copying the file every time, symlink the repo file into the watched folder.

Linux:

```bash
mkdir -p ~/.config/wf-themes/sites
ln -sf "$PWD/custom-sites/my-site.css" ~/.config/wf-themes/sites/my-site.css
```

Windows PowerShell, from the repo root:

```powershell
New-Item -ItemType Directory -Force "$env:APPDATA\wf-themes\config\sites"
New-Item -ItemType SymbolicLink `
  -Path "$env:APPDATA\wf-themes\config\sites\my-site.css" `
  -Target "$PWD\custom-sites\my-site.css" `
  -Force
```

If Windows refuses to create the symlink, enable Developer Mode or run
PowerShell as Administrator. Copying the file is simpler and works everywhere.

## Troubleshooting

- Confirm the browser extension is version `0.2.0` or newer.
- Confirm the updated native host is installed. On Windows, rerun:

  ```powershell
  .\windows\install.ps1
  ```

- Confirm the file is in the watched runtime folder, not only in `custom-sites/`.
- Confirm the target tab URL matches your `domain(...)` or `url-prefix(...)`.
- Reload the target tab after adding the first style for a new website.
- Open the extension background console from `about:debugging` and look for
  custom style parse warnings.
