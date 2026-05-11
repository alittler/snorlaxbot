#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="alittler"
REPO_NAME="snorlaxbot"
BRANCH="${BRANCH:-main}"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  DEFAULT_INSTALL_DIR="/opt/snorlaxbot"
  DEFAULT_BIN_LINK="/usr/local/bin/snorlaxbot"
else
  DEFAULT_INSTALL_DIR="${HOME}/.local/share/snorlaxbot"
  DEFAULT_BIN_LINK="${HOME}/.local/bin/snorlaxbot"
fi

INSTALL_DIR="${INSTALL_DIR:-${DEFAULT_INSTALL_DIR}}"
BIN_LINK="${BIN_LINK:-${DEFAULT_BIN_LINK}}"
SCRIPT_NAME="snorlaxbot.sh"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/${SCRIPT_NAME}"

log() {
  printf '[install] %s\n' "$*"
}

die() {
  printf '[error] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

main() {
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
  local bin_dir
  bin_dir="$(dirname "${BIN_LINK}")"
  mkdir -p "${bin_dir}"
  rm -f "${BIN_LINK}"
  ln -s "${INSTALL_DIR}/${SCRIPT_NAME}" "${BIN_LINK}"

  log "Installation complete"
  echo
  echo "Run with:"
  echo "  ${BIN_LINK}"
  local bin_in_path=0
  local path_entry
  IFS=':' read -r -a path_entries <<< "${PATH:-}"
  for path_entry in "${path_entries[@]}"; do
    if [[ "${path_entry}" == "${bin_dir}" ]]; then
      bin_in_path=1
      break
    fi
  done
  if [[ "${bin_in_path}" -eq 0 ]]; then
    echo
    echo "Note:"
    echo "  ${bin_dir} is not currently in PATH for this shell."
    echo "  Add it for this session with:"
    echo "    export PATH=\"${bin_dir}:\$PATH\""
  fi
  echo
  echo "Or directly:"
  echo "  /bin/bash ${INSTALL_DIR}/${SCRIPT_NAME}"
}

main "$@"
