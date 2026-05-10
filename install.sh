#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="alittler"
REPO_NAME="snorlaxbot"
BRANCH="${BRANCH:-main}"

INSTALL_DIR="${INSTALL_DIR:-/opt/snorlaxbot}"
BIN_LINK="${BIN_LINK:-/usr/local/bin/snorlaxbot}"
SCRIPT_NAME="snorlaxbot.sh"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/${SCRIPT_NAME}"

log() {
  printf '[install] %s\n' "$*"
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Please run as root (for example: curl -fsSL ... | sudo bash)"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

main() {
  require_root
  require_cmd curl
  require_cmd install
  require_cmd chmod
  require_cmd ln
  require_cmd mkdir
  require_cmd rm

  log "Installing ${REPO_NAME} to ${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}"

  log "Downloading ${SCRIPT_NAME}"
  curl -fsSL "${SCRIPT_URL}" -o "${INSTALL_DIR}/${SCRIPT_NAME}"

  log "Setting executable permissions"
  chmod 0755 "${INSTALL_DIR}/${SCRIPT_NAME}"

  log "Creating launcher symlink at ${BIN_LINK}"
  mkdir -p "$(dirname "${BIN_LINK}")"
  rm -f "${BIN_LINK}"
  ln -s "${INSTALL_DIR}/${SCRIPT_NAME}" "${BIN_LINK}"

  log "Installation complete"
  echo
  echo "Run with:"
  echo "  ${BIN_LINK}"
  echo
  echo "Or directly:"
  echo "  /bin/bash ${INSTALL_DIR}/${SCRIPT_NAME}"
}

main "$@"
