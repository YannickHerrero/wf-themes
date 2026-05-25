#!/usr/bin/env bash
# Copy the 5 all-in-one theme CSS files from the stylus repo into the
# extension package. Run by hand after stylus changes; the two repos are
# intentionally independent (no submodule, no shared build).
#
# Usage: bash scripts/sync-themes.sh [path/to/stylus]
# Default source: ~/dev/stylus

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-${HOME}/dev/stylus}/styles/all"
DST="${REPO_DIR}/extension/themes"

if [[ ! -d "${SRC}" ]]; then
  echo "error: stylus all-in-one CSS dir not found at ${SRC}" >&2
  echo "       pass the stylus repo path as the first argument, or check out stylus to ~/dev/stylus" >&2
  exit 1
fi

mkdir -p "${DST}"

# Normalize the GitHub @-moz-document matcher on copy.
#
# stylus ships an `@-moz-document regexp("https://github.com(?!(...).*$"), ...`
# block to exclude GitHub's marketing pages (/home, /features, etc.). The
# regexp() form of @-moz-document is unreliable when CSS is injected via
# tabs.insertCSS({cssOrigin:"user"}) — Firefox silently drops it, while the
# domain() form works. Substituting domain("github.com") restores theming
# on github.com at the cost of also theming marketing pages, which is fine.
GITHUB_REGEXP_RE='@-moz-document regexp("https:\\/\\/github\\.com[^"]*")'
GITHUB_DOMAIN='@-moz-document domain("github.com")'

for theme in paper stone sage clay ink; do
  sed "s|${GITHUB_REGEXP_RE}|${GITHUB_DOMAIN}|g" \
    "${SRC}/${theme}.user.css" > "${DST}/${theme}.css"
  echo "[wf-themes] synced ${theme}.css (github regexp normalised to domain)"
done
