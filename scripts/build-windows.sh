#!/usr/bin/env bash
# Cross-compile wf-themes-host for Windows (x86_64) and refresh the copy
# checked into windows/. Run from WSL or any Linux with the toolchain below
# installed.
#
# Prerequisites:
#   sudo apt install gcc-mingw-w64-x86-64
#   rustup target add x86_64-pc-windows-gnu
#
# Usage: bash scripts/build-windows.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="x86_64-pc-windows-gnu"
OUTPUT_NAME="wf-themes-host.exe"
COMMITTED_PATH="${REPO_DIR}/windows/${OUTPUT_NAME}"

echo "[wf-themes] cross-compiling for ${TARGET}..."
cargo build --release \
  --manifest-path "${REPO_DIR}/native-host/Cargo.toml" \
  --target "${TARGET}"

SRC="${REPO_DIR}/native-host/target/${TARGET}/release/${OUTPUT_NAME}"
install -m 0755 "${SRC}" "${COMMITTED_PATH}"

size=$(du -h "${COMMITTED_PATH}" | cut -f1)
echo "[wf-themes] wrote ${COMMITTED_PATH} (${size})"
echo "            commit it: git add windows/${OUTPUT_NAME} && git commit"
