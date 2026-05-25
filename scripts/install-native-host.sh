#!/usr/bin/env bash
# Build the native host binary, install it to ~/.local/bin, and register it
# with Firefox by writing the native messaging manifest with an absolute path.
#
# Usage: bash scripts/install-native-host.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST_BIN_NAME="wf-themes-host"
INSTALL_DIR="${HOME}/.local/bin"
HOST_PATH="${INSTALL_DIR}/${HOST_BIN_NAME}"
NM_DIR="${HOME}/.mozilla/native-messaging-hosts"
NM_MANIFEST="${NM_DIR}/com.yannick.wf_themes.json"
TEMPLATE="${REPO_DIR}/packaging/com.yannick.wf_themes.json.tpl"

echo "[wf-themes] building release binary..."
cargo build --release --manifest-path "${REPO_DIR}/native-host/Cargo.toml"

echo "[wf-themes] installing binary to ${HOST_PATH}"
mkdir -p "${INSTALL_DIR}"
install -m 0755 "${REPO_DIR}/native-host/target/release/${HOST_BIN_NAME}" "${HOST_PATH}"

echo "[wf-themes] writing native messaging manifest to ${NM_MANIFEST}"
mkdir -p "${NM_DIR}"
sed "s|__HOST_PATH__|${HOST_PATH}|g" "${TEMPLATE}" > "${NM_MANIFEST}"

echo "[wf-themes] done."
echo "  host:     ${HOST_PATH}"
echo "  manifest: ${NM_MANIFEST}"
