#!/usr/bin/env bash
# Zip the extension/ directory into dist/wf-themes.xpi for sideloading or
# submitting to AMO for signing.
#
# Uses python3's zipfile module rather than the `zip` binary so the script
# works on minimal systems (e.g. WSL) without an apt install.
#
# Usage: bash scripts/build-xpi.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${REPO_DIR}/dist"
XPI="${DIST_DIR}/wf-themes.xpi"

mkdir -p "${DIST_DIR}"
rm -f "${XPI}"

python3 - "${REPO_DIR}/extension" "${XPI}" <<'PY'
import os, sys, zipfile

src, dst = sys.argv[1], sys.argv[2]
skip = {".DS_Store"}

with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            if f in skip:
                continue
            path = os.path.join(root, f)
            z.write(path, os.path.relpath(path, src))
PY

size=$(du -h "${XPI}" | cut -f1)
echo "[wf-themes] built ${XPI} (${size})"
