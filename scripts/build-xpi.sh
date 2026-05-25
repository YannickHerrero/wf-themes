#!/usr/bin/env bash
# Zip the extension/ directory into dist/wf-themes.xpi for sideloading or
# submitting to AMO for signing.
#
# Usage: bash scripts/build-xpi.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${REPO_DIR}/dist"
XPI="${DIST_DIR}/wf-themes.xpi"

mkdir -p "${DIST_DIR}"
rm -f "${XPI}"

cd "${REPO_DIR}/extension"
zip -r "${XPI}" . -x "*.DS_Store" >/dev/null

echo "[wf-themes] built ${XPI} ($(du -h "${XPI}" | cut -f1))"
