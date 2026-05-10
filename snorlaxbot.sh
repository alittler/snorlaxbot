#!/bin/bash
# ============================================================
#  snorlaxbot.sh
#  FileBot AMC — Terminal Management Interface
# ============================================================

# ── Script self-location ──────────────────────────────────
SCRIPT_PATH=""
SCRIPT_DIR=""
ENV_FILE=""
LOG_DIR=""
LOG_FILE=""
IMPORT_REPORT_FILE=""

resolve_script_path() {
  local source="${BASH_SOURCE[0]}"
  while [ -h "$source" ]; do
    local dir
    dir="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
    source="$(readlink "$source")"
    [[ "$source" != /* ]] && source="$dir/$source"
  done
  SCRIPT_PATH="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)/$(basename "$source")"
  SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
  ENV_FILE="$SCRIPT_DIR/.env"
  LOG_DIR="$SCRIPT_DIR/logs"
  LOG_FILE="$LOG_DIR/snorlaxbot.log"
  IMPORT_REPORT_FILE="$LOG_DIR/import-report.log"
}

# ── Colors ────────────────────────────────────────────────
CY='\033[0;36m'   # cyan       — labels, brackets
GR='\033[0;32m'   # green      — menu items
YE='\033[1;33m'   # yellow     — warnings / highlights
RE='\033[0;31m'   # red        — errors
BL='\033[0;34m'   # blue       — ascii art / dividers
WH='\033[1;37m'   # white bold — section headers
DI='\033[2m'      # dim
N='\033[0m'       # reset

# ── Defaults ──────────────────────────────────────────────
DEFAULT_FINISHED_DIR="/mnt/Media/Torrents/finished"
DEFAULT_TEMP_DIR="/mnt/Media/Torrents/temp"
DEFAULT_WATCH_DIR="/mnt/Media/Torrents/watch"
DEFAULT_OUTPUT_BASE="/mnt/Media"
DEFAULT_MOVIES_DIR="/mnt/Media/Movies"
DEFAULT_SERIES_DIR="/mnt/TV_Shows/TV Shows"
DEFAULT_PLEX_HOST="localhost"
DEFAULT_PLEX_URL="http://localhost:32400/identity"
DEFAULT_CLEANUP_DAYS=7
DEFAULT_BBB_TORRENT_URL="https://webtorrent.io/torrents/big-buck-bunny.torrent"

# Config variables
FINISHED_DIR=""
TEMP_DIR=""
WATCH_DIR=""
OUTPUT_BASE=""
MOVIES_DIR=""
SERIES_DIR=""
PLEX_HOST=""
PLEX_URL=""
PLEX_TOKEN=""
GMAIL_USER=""
GMAIL_PASS=""
PUSHOVER_USER=""
PUSHOVER_TOKEN=""
QB_CONFIG_PATH=""
QBITTORRENT_VARIANT=""
QBITTORRENT_MODE=""
QBITTORRENT_CONTAINER=""
QBITTORRENT_COMPLETION_HOOK=""
DOCKER_COMPOSE_FILE=""
API_USERNAME=""
API_PASSWORD=""
MOVIE_FORMAT=""
SERIES_FORMAT=""
CLEANUP_DAYS=""
BBB_TORRENT_URL=""
LAST_DISCOVERED_PATHS=""

# ── Load / Save .env ──────────────────────────────────────
load_config() {
  FINISHED_DIR="$DEFAULT_FINISHED_DIR"
  TEMP_DIR="$DEFAULT_TEMP_DIR"
  WATCH_DIR="$DEFAULT_WATCH_DIR"
  OUTPUT_BASE="$DEFAULT_OUTPUT_BASE"
  MOVIES_DIR="$DEFAULT_MOVIES_DIR"
  SERIES_DIR="$DEFAULT_SERIES_DIR"
  PLEX_HOST="$DEFAULT_PLEX_HOST"
  PLEX_URL="$DEFAULT_PLEX_URL"
  PLEX_TOKEN=""
  GMAIL_USER=""
  GMAIL_PASS=""
  PUSHOVER_USER=""
  PUSHOVER_TOKEN=""
  QB_CONFIG_PATH="$HOME/.config/qBittorrent/qBittorrent.conf"
  QBITTORRENT_VARIANT=""
  QBITTORRENT_MODE=""
  QBITTORRENT_CONTAINER=""
  QBITTORRENT_COMPLETION_HOOK=""
  DOCKER_COMPOSE_FILE=""
  API_USERNAME=""
  API_PASSWORD=""
  MOVIE_FORMAT="{n} ({y})"
  SERIES_FORMAT="{n}/{'Season '+s}/{n} - {s00e00} - {t}"
  CLEANUP_DAYS="$DEFAULT_CLEANUP_DAYS"
  BBB_TORRENT_URL="$DEFAULT_BBB_TORRENT_URL"
  LAST_DISCOVERED_PATHS=""

  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
}

save_config() {
  mkdir -p "$LOG_DIR"
  cat > "$ENV_FILE" <<EOF
# SnorlaxBot / FileBot Manager .env — $(date)
FINISHED_DIR="$FINISHED_DIR"
TEMP_DIR="$TEMP_DIR"
WATCH_DIR="$WATCH_DIR"
OUTPUT_BASE="$OUTPUT_BASE"
MOVIES_DIR="$MOVIES_DIR"
SERIES_DIR="$SERIES_DIR"
PLEX_HOST="$PLEX_HOST"
PLEX_URL="$PLEX_URL"
PLEX_TOKEN="$PLEX_TOKEN"
GMAIL_USER="$GMAIL_USER"
GMAIL_PASS="$GMAIL_PASS"
PUSHOVER_USER="$PUSHOVER_USER"
PUSHOVER_TOKEN="$PUSHOVER_TOKEN"
QB_CONFIG_PATH="$QB_CONFIG_PATH"
QBITTORRENT_VARIANT="$QBITTORRENT_VARIANT"
QBITTORRENT_MODE="$QBITTORRENT_MODE"
QBITTORRENT_CONTAINER="$QBITTORRENT_CONTAINER"
QBITTORRENT_COMPLETION_HOOK="$QBITTORRENT_COMPLETION_HOOK"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_FILE"
API_USERNAME="$API_USERNAME"
API_PASSWORD="$API_PASSWORD"
MOVIE_FORMAT="$MOVIE_FORMAT"
SERIES_FORMAT="$SERIES_FORMAT"
CLEANUP_DAYS="$CLEANUP_DAYS"
BBB_TORRENT_URL="$BBB_TORRENT_URL"
LAST_DISCOVERED_PATHS="$LAST_DISCOVERED_PATHS"
EOF
  chmod 600 "$ENV_FILE"
}

# ── Logging ───────────────────────────────────────────────
log_msg() {
  mkdir -p "$LOG_DIR"
  local level="$1"
  shift
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$LOG_FILE"
}

ensure_dirs() {
  mkdir -p "$LOG_DIR" 2>/dev/null || true
}

# ── UI Primitives ─────────────────────────────────────────
divider() { echo -e "${BL}$(printf '═%.0s' {1..70})${N}"; }
thin()    { echo -e "${DI}$(printf '─%.0s' {1..70})${N}"; }
blank()   { echo ""; }

ok()   { echo -e "  ${GR}[  OK  ]${N}  $1"; }
fail() { echo -e "  ${RE}[ FAIL ]${N}  $1"; }
info() { echo -e "  ${CY}[ INFO ]${N}  $1"; }
warn() { echo -e "  ${YE}[ WARN ]${N}  $1"; }

confirm() {
  printf "  ${CY}%s [y/N]:${N} " "$1"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

prompt_input() {
  local label="$1" current="$2"
  printf "  ${CY}%-28s${N} ${DI}[%s]${N}\n  ${GR}>${N} " "$label" "$current"
  read -r REPLY
  [[ -z "$REPLY" ]] && REPLY="$current"
}

prompt_with_default() {
  local label="$1"
  local current="$2"
  local input
  printf "  ${CY}%-28s${N} ${DI}[%s]${N}\n  ${GR}>${N} " "$label" "$current"
  read -r input
  if [ -n "$input" ]; then
    echo "$input"
  else
    echo "$current"
  fi
}

prompt_secret() {
  local label="$1"
  printf "  ${CY}%-28s${N} ${DI}[hidden]${N}\n  ${GR}>${N} " "$label"
  read -rs REPLY
  echo ""
}

pause() {
  blank
  printf "  ${DI}Press Enter to continue...${N}"
  read -r
}

# ── Helper Functions ──────────────────────────────────────
mask_secret() {
  local value="${1:-}"
  if [ -z "$value" ]; then
    echo "<unset>"
  elif [ "${#value}" -le 4 ]; then
    echo "****"
  else
    echo "${value:0:2}****${value: -2}"
  fi
}

normalize_path() {
  local raw_path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$raw_path"
  elif [ -d "$raw_path" ]; then
    (cd "$raw_path" >/dev/null 2>&1 && pwd)
  else
    local base dir
    base="$(basename "$raw_path")"
    dir="$(dirname "$raw_path")"
    (cd "$dir" >/dev/null 2>&1 && printf '%s/%s\n' "$(pwd)" "$base")
  fi
}

build_qb_hook_command() {
  printf '/bin/bash "%s" --auto-filebot "%%L" "%%N" "%%F"' "$SCRIPT_PATH"
}

build_amc_command() {
  local mfmt="$MOVIES_DIR/{n} ({y})"
  local sfmt="$SERIES_DIR/{n}/{'Season '+s}/{n} - {s00e00}"
  local plex_arg="${PLEX_HOST:-localhost}:${PLEX_TOKEN:0:6}***"
  local push_arg="${PUSHOVER_USER:0:6}***:${PUSHOVER_TOKEN:0:6}***"
  local gmail_arg="${GMAIL_USER:-}:***"
  printf 'filebot -script fn:amc \\\n    --output "%s" --action copy -non-strict \\\n    --def "ut_kind=multi" \\\n    --def "ut_dir=%s" \\\n    --def "movieFormat=%s" \\\n    --def "seriesFormat=%s" \\\n    --def plex="%s" \\\n    --def pushover="%s" \\\n    --def gmail="%s"' \
    "$OUTPUT_BASE" "$FINISHED_DIR" "$mfmt" "$sfmt" \
    "$plex_arg" "$push_arg" "$gmail_arg"
}

show_integration_summary() {
  section_header "INTEGRATION SUMMARY"
  cat <<SUMMARY
  Script path:   $SCRIPT_PATH
  Config (.env): $ENV_FILE

  API / Notifications:
    Plex host:      ${PLEX_HOST:-<unset>}
    Plex URL:       ${PLEX_URL:-<unset>}
    Plex token:     $(mask_secret "$PLEX_TOKEN")
    Gmail user:     ${GMAIL_USER:-<unset>}
    Gmail pass:     $(mask_secret "$GMAIL_PASS")
    Pushover user:  $(mask_secret "$PUSHOVER_USER")
    Pushover token: $(mask_secret "$PUSHOVER_TOKEN")
    API username:   ${API_USERNAME:-<unset>}
    API password:   $(mask_secret "$API_PASSWORD")

  Directories:
    FINISHED_DIR:  $FINISHED_DIR
    TEMP_DIR:      $TEMP_DIR
    WATCH_DIR:     $WATCH_DIR
    OUTPUT_BASE:   $OUTPUT_BASE
    MOVIES_DIR:    $MOVIES_DIR
    SERIES_DIR:    $SERIES_DIR
    MOVIE_FORMAT:  $MOVIE_FORMAT
    SERIES_FORMAT: $SERIES_FORMAT
    CLEANUP_DAYS:  $CLEANUP_DAYS

  qBittorrent:
    Variant:       ${QBITTORRENT_VARIANT:-<auto>}
    Mode:          ${QBITTORRENT_MODE:-<auto>}
    Container:     ${QBITTORRENT_CONTAINER:-<none>}
    Config path:   ${QB_CONFIG_PATH:-<unset>}
    Compose file:  ${DOCKER_COMPOSE_FILE:-<unset>}

  Completion hook:
    $(build_qb_hook_command)

  Dynamic AMC command:
$(build_amc_command | sed 's/^/    /')
SUMMARY
  pause
}

# ── Snorlax ASCII Art ─────────────────────────────────────
snorlax_ascii() {
  echo -e "${BL}"
  cat <<'ART'
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣶⣿⣶⣦⣄⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀⣤⣶⣾⣿⣿⣷
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⠿⠿⠿⣿⣿⣿⣿⠿⠿⠿⢿⣿⣿⣿⣿⣿
⠀⠀⠀⠀⠀⢀⡀⣄⠀⠀⠀⠀⠀⠀⠀⣿⣿⠟⠉⠀⢀⣀⠀⠀⠈⠉⠀⠀⣀⣀⠀⠀⠙⢿⣿⣿
⠀⠀⠀⣀⣶⣿⣿⣿⣾⣇⠀⠀⠀⠀⢀⣿⠃⠀⠀⠀⠀⢀⣀⡀⠀⠀⠀⣀⡀⠀⠀⠀⠀⠀⠹⣿
⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⣼⡏⠀⠀⠀⣀⣀⣉⠉⠩⠭⠭⠭⠥⠤⢀⣀⣀⠀⠀⠀⢻⡇
⠀⠀⠀⣸⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⣿⠷⠒⠋⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠑⠒⠼⣧
⠀⠀⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⣦⣀
⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣷⣦⣀
⠀⠀⠀⠈⣿⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣷⣄
⠀⠀⠀⠀⢹⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣷⣄
⠀⠀⠀⠀⠀⣿⣿⣿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣧⡀
⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣶⣤⣄⣠⣤⣤⣶⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷
⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧
⠀⠀⣀⠀⢸⡿⠿⣿⡿⠋⠉⠛⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠉⠀⠻⠿⠟⠉⢙⣿⣿⣿⣿⣿⣿⡇
⠀⠀⢿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠈⠻⠿⢿⡿⣿⠳
⠀⠀⡞⠛⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣇⡀
⢀⣸⣀⡀⠀⠀⠀⠀⣠⣴⣾⣿⣷⣆⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⣰⣿⣿⣿⣿⣷⣦⠀⠀⠀⠀⢿⣿⠿⠃
⠘⢿⡿⠃⠀⠀⠀⣸⣿⣿⣿⣿⣿⡿⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡀⢻⣿⣿⣿⣿⣿⣿⠂⠀⠀⠀⡸
⠀⠀⠳⣄⠀⠀⠀⠹⣿⣿⣿⡿⠛⣠⠾⠿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠿⠿⠳⣄⠙⠛⠿⠿⠛⠉⠀⠀⣀⠜⠁
⠀⠀⠀⠈⠑⠢⠤⠤⠬⠭⠥⠖⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠒⠢⠤⠤⠤⠒⠊
ART
  echo -e "${N}"
}

# ── ASCII Header ──────────────────────────────────────────
print_header() {
  clear
  snorlax_ascii
  echo -e "${BL}"
  echo "    ███████╗██╗██╗     ███████╗██████╗  ██████╗ ████████╗"
  echo "    ██╔════╝██║██║     ██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝"
  echo "    █████╗  ██║██║     █████╗  ██████╔╝██║   ██║   ██║   "
  echo "    ██╔══╝  ██║██║     ██╔══╝  ██╔══██╗██║   ██║   ██║   "
  echo "    ██║     ██║███████╗███████╗██████╔╝╚██████╔╝   ██║   "
  echo "    ╚═╝     ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝    ╚═╝   "
  echo -e "${N}"
  divider

  local cfg_status
  if [[ -f "$ENV_FILE" ]]; then
    cfg_status="${GR}ACTIVE${N}"
  else
    cfg_status="${RE}NO CONFIG${N}"
  fi

  local filebot_status
  if command -v filebot &>/dev/null; then
    filebot_status="${GR}INSTALLED${N}"
  else
    filebot_status="${YE}NOT FOUND${N}"
  fi

  echo -e "  ${CY}HOST:${N} $(hostname)   ${CY}CONFIG:${N} $cfg_status   ${CY}FILEBOT:${N} $filebot_status"
  echo -e "  ${DI}Script: $SCRIPT_PATH${N}"
  echo -e "  ${DI}ENV: $ENV_FILE${N}"
  divider
  blank
}

# ── Section header (inside submenus) ─────────────────────
section_header() {
  clear
  snorlax_ascii
  echo -e "${BL}"
  echo "    ███████╗██╗██╗     ███████╗██████╗  ██████╗ ████████╗"
  echo "    ██╔════╝██║██║     ██╔════╝██╔══██╗██╔═══██╗╚══██╔══╝"
  echo "    █████╗  ██║██║     █████╗  ██████╔╝██║   ██║   ██║   "
  echo "    ██╔══╝  ██║██║     ██╔══╝  ██╔══██╗██║   ██║   ██║   "
  echo "    ██║     ██║███████╗███████╗██████╔╝╚██████╔╝   ██║   "
  echo "    ╚═╝     ╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝    ╚═╝   "
  echo -e "${N}"
  divider
  echo -e "  ${WH}$1${N}"
  divider
  blank
}

# ════════════════════════════════════════════════════════════
#  SETUP & CONFIGURATION
# ════════════════════════════════════════════════════════════

setup_install_deps() {
  section_header "SETUP & CONFIGURATION  //  INSTALL DEPENDENCIES"
  info "Packages: filebot  openjdk-17-jre  curl  docker.io  docker-compose  qbittorrent  qbittorrent-nox  transmission-cli"
  blank
  confirm "Run apt update + install?" || return
  blank
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get install -y filebot openjdk-17-jre curl docker.io docker-compose \
    qbittorrent qbittorrent-nox transmission-cli 2>/dev/null || true
  blank
  if command -v filebot &>/dev/null; then
    ok "filebot $(filebot --version 2>/dev/null | head -1)"
  else
    fail "filebot not found — check your apt sources"
  fi
  pause
}

setup_configure_dirs() {
  section_header "SETUP & CONFIGURATION  //  DIRECTORIES"
  info "Press Enter to keep current value"
  blank
  prompt_input "Source (finished)" "$FINISHED_DIR";  FINISHED_DIR="$REPLY"
  prompt_input "Source (temp)"     "$TEMP_DIR";      TEMP_DIR="$REPLY"
  prompt_input "Watch dir"         "$WATCH_DIR";     WATCH_DIR="$REPLY"
  prompt_input "Output base"       "$OUTPUT_BASE";   OUTPUT_BASE="$REPLY"
  prompt_input "Movies dir"        "$MOVIES_DIR";    MOVIES_DIR="$REPLY"
  prompt_input "TV Shows dir"      "$SERIES_DIR";    SERIES_DIR="$REPLY"
  mkdir -p "$MOVIES_DIR" "$SERIES_DIR" 2>/dev/null || true
  save_config
  blank
  ok "Saved → $ENV_FILE"
  pause
}

setup_configure_creds() {
  section_header "SETUP & CONFIGURATION  //  API CREDENTIALS"
  info "Leave blank to keep existing value"
  blank

  echo -e "  ${WH}PLEX${N}"
  prompt_input  "Host"         "$PLEX_HOST"; PLEX_HOST="$REPLY"
  prompt_input  "Identity URL" "$PLEX_URL";  PLEX_URL="$REPLY"
  prompt_secret "Token";                     [[ -n "$REPLY" ]] && PLEX_TOKEN="$REPLY"
  blank

  echo -e "  ${WH}GMAIL${N}"
  prompt_input  "Address"      "$GMAIL_USER"; GMAIL_USER="$REPLY"
  prompt_secret "App password";               [[ -n "$REPLY" ]] && GMAIL_PASS="$REPLY"
  blank

  echo -e "  ${WH}PUSHOVER${N}"
  prompt_secret "User key";   [[ -n "$REPLY" ]] && PUSHOVER_USER="$REPLY"
  prompt_secret "API token";  [[ -n "$REPLY" ]] && PUSHOVER_TOKEN="$REPLY"
  blank

  echo -e "  ${WH}OTHER${N}"
  prompt_input  "API username" "$API_USERNAME"; API_USERNAME="$REPLY"
  prompt_secret "API password";                [[ -n "$REPLY" ]] && API_PASSWORD="$REPLY"

  save_config
  blank
  ok "Credentials saved → $ENV_FILE (chmod 600)"
  pause
}

setup_configure_processing() {
  section_header "SETUP & CONFIGURATION  //  PROCESSING DEFAULTS"
  blank
  prompt_input "Movie format"    "$MOVIE_FORMAT";    MOVIE_FORMAT="$REPLY"
  prompt_input "Series format"   "$SERIES_FORMAT";   SERIES_FORMAT="$REPLY"
  prompt_input "Cleanup days"    "$CLEANUP_DAYS";    CLEANUP_DAYS="$REPLY"
  prompt_input "BBB torrent URL" "$BBB_TORRENT_URL"; BBB_TORRENT_URL="$REPLY"
  save_config
  blank
  ok "Processing defaults saved → $ENV_FILE"
  pause
}

setup_show_command() {
  section_header "SETUP & CONFIGURATION  //  CURRENT AMC / HOOK COMMANDS"
  blank
  echo -e "  ${WH}Dynamic AMC command (secrets truncated):${N}"
  blank
  build_amc_command | sed 's/^/    /'
  blank
  echo -e "  ${WH}qBittorrent completion hook:${N}"
  blank
  echo -e "    $(build_qb_hook_command)"
  blank
  echo -e "  ${DI}Secrets truncated — full values used at runtime${N}"
  pause
}

# ── qBittorrent / Docker detection ────────────────────────
detect_qbittorrent_local() {
  local detected=""
  if pgrep -x qbittorrent >/dev/null 2>&1 || command -v qbittorrent >/dev/null 2>&1; then
    detected="qbittorrent"
  fi
  if pgrep -x qbittorrent-nox >/dev/null 2>&1 || command -v qbittorrent-nox >/dev/null 2>&1; then
    detected="${detected:+$detected,}qbittorrent-nox"
  fi
  echo "$detected"
}

find_qbittorrent_containers() {
  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi
  docker ps --format '{{.Names}}|{{.Image}}' 2>/dev/null \
    | awk -F'|' 'tolower($2) ~ /qbittorrent|qbit/ {print $1}'
}

inspect_container_mounts() {
  local container_name="$1"
  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi
  docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' \
    "$container_name" 2>/dev/null
}

discover_likely_paths() {
  local discovered_finished="" discovered_temp="" discovered_watch="" discovered_config=""

  if [ -d "$HOME/Downloads" ]; then
    discovered_finished="${HOME}/Downloads/finished"
    discovered_temp="${HOME}/Downloads/incomplete"
    discovered_watch="${HOME}/Downloads/watch"
  fi

  local container
  while IFS= read -r container; do
    [ -z "$container" ] && continue
    local mounts
    mounts="$(inspect_container_mounts "$container")"
    [ -z "$mounts" ] && continue
    if [ -z "$discovered_config" ]; then
      discovered_config="$(printf '%s\n' "$mounts" | awk '/-> \/config/ {print $1; exit}')"
    fi
    if [ -z "$discovered_finished" ]; then
      discovered_finished="$(printf '%s\n' "$mounts" | awk 'tolower($0) ~ /complete|finished|downloads/ {print $1; exit}')"
    fi
    if [ -z "$discovered_temp" ]; then
      discovered_temp="$(printf '%s\n' "$mounts" | awk 'tolower($0) ~ /incomplete|temp/ {print $1; exit}')"
    fi
    if [ -z "$discovered_watch" ]; then
      discovered_watch="$(printf '%s\n' "$mounts" | awk 'tolower($0) ~ /watch/ {print $1; exit}')"
    fi
  done < <(find_qbittorrent_containers)

  [ -n "$discovered_finished" ] && FINISHED_DIR="$discovered_finished"
  [ -n "$discovered_temp" ]     && TEMP_DIR="$discovered_temp"
  [ -n "$discovered_watch" ]    && WATCH_DIR="$discovered_watch"
  if [ -n "$discovered_config" ]; then
    QB_CONFIG_PATH="$discovered_config/qBittorrent/qBittorrent.conf"
  fi

  LAST_DISCOVERED_PATHS="finished=$discovered_finished;temp=$discovered_temp;watch=$discovered_watch;config=$discovered_config"
}

setup_check_deps() {
  section_header "SETUP & CONFIGURATION  //  DEPENDENCY & ENVIRONMENT CHECKS"
  local missing=0

  _chk() {
    if command -v "$1" >/dev/null 2>&1; then
      ok "$2"
      return 0
    else
      fail "$2"
      return 1
    fi
  }

  _chk filebot         "FileBot (filebot)" || missing=$((missing + 1))
  _chk java            "Java (java)"       || missing=$((missing + 1))
  _chk curl            "curl"              || missing=$((missing + 1))
  _chk docker          "Docker (docker)"   || missing=$((missing + 1))
  if command -v docker-compose >/dev/null 2>&1; then
    ok "docker-compose"
  elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker Compose plugin (docker compose)"
  else
    fail "Docker Compose (docker-compose / docker compose)"
    missing=$((missing + 1))
  fi
  if command -v qbittorrent >/dev/null 2>&1; then
    ok "qBittorrent GUI (qbittorrent)"
  else
    warn "qBittorrent GUI not found (optional)"
  fi
  if command -v qbittorrent-nox >/dev/null 2>&1; then
    ok "qBittorrent Nox (qbittorrent-nox)"
  else
    warn "qBittorrent Nox not found (optional)"
  fi
  _chk transmission-cli "transmission-cli" || missing=$((missing + 1))
  blank

  echo -e "  ${WH}Common shell utilities:${N}"
  local util
  for util in bash awk sed grep find sort cut tr head tail xargs df du stat chmod mkdir realpath; do
    if command -v "$util" >/dev/null 2>&1; then
      echo -e "    ${GR}[OK]${N}   $util"
    else
      echo -e "    ${RE}[MISS]${N} $util"
      missing=$((missing + 1))
    fi
  done

  blank
  if [ "$missing" -eq 0 ]; then
    ok "Environment looks ready."
  else
    warn "$missing required item(s) missing."
    info "Install hint (Debian/Ubuntu):"
    echo "    sudo apt-get install -y filebot default-jre curl docker.io docker-compose"
    echo "    sudo apt-get install -y qbittorrent qbittorrent-nox transmission-cli"
  fi
  pause
}

setup_first_time_discovery() {
  section_header "SETUP & CONFIGURATION  //  FIRST-TIME DISCOVERY & PATH MAPPING"
  info "Scanning for qBittorrent instances and likely paths..."
  blank

  discover_likely_paths

  if [ -n "$LAST_DISCOVERED_PATHS" ]; then
    info "Discovered hints:"
    echo "    $LAST_DISCOVERED_PATHS"
    blank
  fi

  local local_detected
  local_detected="$(detect_qbittorrent_local)"
  if [ -n "$local_detected" ]; then
    ok "Local qBittorrent: $local_detected"
    QBITTORRENT_MODE="native"
    QBITTORRENT_VARIANT="$local_detected"
  else
    warn "No local qBittorrent process detected."
  fi

  local first_container
  first_container="$(find_qbittorrent_containers | head -n 1)"
  if [ -n "$first_container" ]; then
    ok "Docker qBittorrent container: $first_container"
    QBITTORRENT_MODE="docker"
    QBITTORRENT_CONTAINER="$first_container"
  fi
  blank

  info "Review / adjust discovered paths (Enter to keep current):"
  blank
  prompt_input "FINISHED_DIR"            "$FINISHED_DIR";   FINISHED_DIR="$REPLY"
  prompt_input "TEMP_DIR"                "$TEMP_DIR";       TEMP_DIR="$REPLY"
  prompt_input "WATCH_DIR"               "$WATCH_DIR";      WATCH_DIR="$REPLY"
  prompt_input "OUTPUT_BASE"             "$OUTPUT_BASE";    OUTPUT_BASE="$REPLY"
  prompt_input "MOVIES_DIR"              "$MOVIES_DIR";     MOVIES_DIR="$REPLY"
  prompt_input "SERIES_DIR"              "$SERIES_DIR";     SERIES_DIR="$REPLY"
  prompt_input "qBittorrent config path" "$QB_CONFIG_PATH"; QB_CONFIG_PATH="$REPLY"

  QBITTORRENT_COMPLETION_HOOK="$(build_qb_hook_command)"
  save_config
  blank
  ok "Saved → $ENV_FILE"
  pause
}

setup_qb_discovery() {
  section_header "SETUP & CONFIGURATION  //  QBITTORRENT DETECTION"
  local local_detected
  local_detected="$(detect_qbittorrent_local)"
  if [ -n "$local_detected" ]; then
    ok "Local qBittorrent detected: $local_detected"
  else
    warn "Local qBittorrent binaries/processes not detected."
  fi
  blank

  local containers
  containers="$(find_qbittorrent_containers)"
  if [ -n "$containers" ]; then
    ok "Likely qBittorrent Docker containers:"
    echo "$containers" | sed 's/^/    /'
    blank
    local c
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      echo -e "  ${WH}Mounts for container: $c${N}"
      inspect_container_mounts "$c" | sed 's/^/    /'
    done <<< "$containers"
  else
    warn "No likely qBittorrent Docker containers detected."
  fi
  blank

  discover_likely_paths
  info "Path hints: ${LAST_DISCOVERED_PATHS:-none}"
  save_config
  pause
}

setup_install_hook() {
  section_header "SETUP & CONFIGURATION  //  INSTALL QBITTORRENT COMPLETION HOOK"
  local cmd
  cmd="$(build_qb_hook_command)"

  echo -e "  ${WH}Use this command in qBittorrent:${N}"
  echo -e "  ${DI}Downloads → Run external program on torrent completion${N}"
  blank
  echo -e "    ${GR}$cmd${N}"
  blank

  QBITTORRENT_COMPLETION_HOOK="$cmd"

  if [ -n "$QB_CONFIG_PATH" ] && [ -f "$QB_CONFIG_PATH" ]; then
    info "Detected config file: $QB_CONFIG_PATH"
    if grep -Fq "$cmd" "$QB_CONFIG_PATH"; then
      ok "Hook already configured with current script path."
    else
      warn "Hook not found in config."
      if confirm "Attempt safe in-file update for Program line?"; then
        local backup_path="$QB_CONFIG_PATH.bak.$(date +%s)"
        if ! cp "$QB_CONFIG_PATH" "$backup_path"; then
          fail "Failed to create backup at $backup_path"
          pause
          return
        fi
        ok "Backup created: $backup_path"
        awk -v cmd="$cmd" '
          BEGIN { has_program=0; has_toggle=0 }
          /^Downloads\\Program=/ { print "Downloads\\Program=" cmd; has_program=1; next }
          /^Downloads\\RunExternalProgram=/ { print "Downloads\\RunExternalProgram=true"; has_toggle=1; next }
          { print }
          END {
            if (!has_program) print "Downloads\\Program=" cmd
            if (!has_toggle) print "Downloads\\RunExternalProgram=true"
          }
        ' "$QB_CONFIG_PATH" > "$QB_CONFIG_PATH.tmp" \
          && mv "$QB_CONFIG_PATH.tmp" "$QB_CONFIG_PATH"
        ok "Config updated. Restart qBittorrent to apply."
      fi
    fi
  else
    warn "qBittorrent config not found at: ${QB_CONFIG_PATH:-<unset>}"
    info "Manual update required in qBittorrent settings."
  fi

  if [ -n "$DOCKER_COMPOSE_FILE" ] && [ -f "$DOCKER_COMPOSE_FILE" ]; then
    blank
    info "Compose file: $DOCKER_COMPOSE_FILE"
    grep -nE "qbit|qbittorrent|volumes?|downloads|watch|config" "$DOCKER_COMPOSE_FILE" || true
  fi

  save_config
  pause
}

setup_verify_hook() {
  section_header "SETUP & CONFIGURATION  //  VERIFY QBITTORRENT HOOK"
  local expected
  expected="$(build_qb_hook_command)"
  echo -e "  ${WH}Expected hook command:${N}"
  echo -e "    ${GR}$expected${N}"
  blank

  local verified=0
  if [ -n "$QB_CONFIG_PATH" ] && [ -f "$QB_CONFIG_PATH" ]; then
    info "Inspecting: $QB_CONFIG_PATH"
    local current
    current="$(grep '^Downloads\\Program=' "$QB_CONFIG_PATH" 2>/dev/null | head -n 1 | cut -d'=' -f2-)"
    echo -e "  ${CY}Current configured Program:${N} ${current:-<unset>}"
    if [ "$current" = "$expected" ]; then
      ok "Script path in qBittorrent hook matches current script path."
      verified=1
    else
      warn "Script path mismatch — hook may be stale."
    fi
  else
    warn "qBittorrent config file not found for direct verification."
  fi

  if [ "$verified" -eq 0 ]; then
    blank
    info "Manual guidance:"
    echo "  1) Open qBittorrent settings → Downloads"
    echo "  2) Set 'Run external program on torrent completion' to exactly:"
    echo -e "     ${GR}$expected${N}"
    echo "  3) Save and re-check from this menu"
  fi
  pause
}

setup_qb_optimization() {
  section_header "SETUP & CONFIGURATION  //  QBITTORRENT OPTIMIZATION"
  echo -e "  ${WH}Path consistency checks:${N}"
  local var val
  for var in FINISHED_DIR TEMP_DIR WATCH_DIR OUTPUT_BASE MOVIES_DIR SERIES_DIR; do
    val="${!var}"
    if [ -d "$val" ]; then
      ok "$var: $val"
    else
      warn "$var missing: $val"
    fi
  done
  blank

  local containers
  containers="$(find_qbittorrent_containers)"
  if [ -n "$containers" ]; then
    echo -e "  ${WH}Docker container mount suggestions:${N}"
    local c
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      echo "  Container: $c"
      inspect_container_mounts "$c" | sed 's/^/    /'
    done <<< "$containers"
    blank
    info "Ensure FINISHED_DIR/TEMP_DIR host paths are accessible to FileBot."
  else
    warn "No qBittorrent Docker containers detected."
  fi

  if [ -n "$DOCKER_COMPOSE_FILE" ] && [ -f "$DOCKER_COMPOSE_FILE" ]; then
    blank
    info "Compose inspection hints from: $DOCKER_COMPOSE_FILE"
    grep -nE 'qbit|qbittorrent|volumes?|downloads?|watch|config' "$DOCKER_COMPOSE_FILE" || true
  fi
  pause
}

# ════════════════════════════════════════════════════════════
#  CORE PROCESSING
# ════════════════════════════════════════════════════════════

_validate() {
  local errors=()
  [[ -z "$PLEX_TOKEN" ]]     && errors+=("Plex token not set")
  [[ -z "$GMAIL_USER" ]]     && errors+=("Gmail user not set")
  [[ -z "$GMAIL_PASS" ]]     && errors+=("Gmail password not set")
  [[ -z "$PUSHOVER_USER" ]]  && errors+=("Pushover user key not set")
  [[ -z "$PUSHOVER_TOKEN" ]] && errors+=("Pushover API token not set")
  [[ ! -d "$FINISHED_DIR" ]] && errors+=("Source dir missing: $FINISHED_DIR")
  if [[ ${#errors[@]} -gt 0 ]]; then
    for e in "${errors[@]}"; do warn "$e"; done
    blank
    confirm "Continue anyway (notifications may fail)?" || return 1
  fi
  return 0
}

_run_filebot() {
  local extra_flags="$1"
  local source_dir="$2"
  local mfmt="$MOVIES_DIR/{n} ({y})"
  local sfmt="$SERIES_DIR/{n}/{'Season '+s}/{n} - {s00e00}"

  [[ -z "$source_dir" ]] && source_dir="$FINISHED_DIR"

  log_msg "INFO" "Running FileBot source=$source_dir flags=$extra_flags"

  # shellcheck disable=SC2086
  filebot -script fn:amc \
    --output "$OUTPUT_BASE" \
    --action copy \
    -non-strict \
    $extra_flags \
    --def "ut_kind=multi" \
    --def "ut_dir=$source_dir" \
    --def "movieFormat=$mfmt" \
    --def "seriesFormat=$sfmt" \
    --def plex="$PLEX_HOST:$PLEX_TOKEN" \
    --def pushover="$PUSHOVER_USER:$PUSHOVER_TOKEN" \
    --def gmail="$GMAIL_USER:$GMAIL_PASS"

  local c=$?
  if [ $c -eq 0 ]; then
    log_msg "INFO" "FileBot success source=$source_dir"
    printf '%s | success | %s\n' "$(date '+%F %T')" "$source_dir" >> "$IMPORT_REPORT_FILE"
  else
    log_msg "ERROR" "FileBot exit=$c source=$source_dir"
    printf '%s | failure | %s\n' "$(date '+%F %T')" "$source_dir" >> "$IMPORT_REPORT_FILE"
  fi
  return $c
}

normalize_and_run() {
  local target_path="$1"
  local extra_flags="${2:-}"
  local normalized
  normalized="$(normalize_path "$target_path")"

  if [ ! -e "$normalized" ]; then
    fail "Target does not exist: $normalized"
    log_msg "ERROR" "Missing target path: $normalized"
    return 1
  fi

  _run_filebot "$extra_flags" "$normalized"
}

core_run_finished() {
  section_header "CORE PROCESSING  //  RUN MOVE (FINISHED)"
  _validate || return
  info "Source: $FINISHED_DIR"
  info "Output: $OUTPUT_BASE"
  blank
  confirm "Execute FileBot AMC now?" || return
  blank
  _run_filebot "" "$FINISHED_DIR"
  local c=$?
  blank
  [[ $c -eq 0 ]] && ok "Completed (exit $c)" || fail "Exited with code $c"
  pause
}

core_run_temp() {
  section_header "CORE PROCESSING  //  RUN MOVE (TEMP)"
  _validate || return
  [[ ! -d "$TEMP_DIR" ]] && { fail "Temp source dir missing: $TEMP_DIR"; pause; return; }
  info "Source: $TEMP_DIR"
  info "Output: $OUTPUT_BASE"
  blank
  confirm "Run FileBot on $TEMP_DIR?" || return
  blank
  _run_filebot "" "$TEMP_DIR"
  local c=$?
  blank
  [[ $c -eq 0 ]] && ok "Completed (exit $c)" || fail "Exited with code $c"
  pause
}

core_run_force() {
  section_header "CORE PROCESSING  //  FORCED RUN (IGNORE HISTORY)"
  _validate || return
  warn "This ignores AMC history — files already moved may be re-processed"
  blank
  confirm "Continue?" || return
  blank
  _run_filebot "--def ignoreHistory=y" "$FINISHED_DIR"
  local c=$?
  blank
  [[ $c -eq 0 ]] && ok "Completed (exit $c)" || fail "Exited with code $c"
  pause
}

core_run_dry() {
  section_header "CORE PROCESSING  //  SIMULATION MODE (DRY RUN)"
  _validate || return
  info "No files will be moved — output only"
  blank
  confirm "Run simulation?" || return
  blank
  _run_filebot "--action test" "$FINISHED_DIR"
  local c=$?
  blank
  [[ $c -eq 0 ]] && ok "Simulation complete (exit $c)" || fail "Exited with code $c"
  if [ -f "$IMPORT_REPORT_FILE" ]; then
    blank
    echo -e "  ${DI}Recent import log:${N}"
    tail -n 5 "$IMPORT_REPORT_FILE"
  fi
  pause
}

# ════════════════════════════════════════════════════════════
#  SYSTEM & MAINTENANCE
# ════════════════════════════════════════════════════════════

maint_view_logs() {
  section_header "SYSTEM & MAINTENANCE  //  VIEW LOGS"
  if [[ ! -f "$LOG_FILE" ]]; then
    warn "Log file not found: $LOG_FILE"
    pause
    return
  fi
  info "Last 60 lines of: $LOG_FILE"
  blank
  tail -n 60 "$LOG_FILE"
  pause
}

maint_search_logs() {
  section_header "SYSTEM & MAINTENANCE  //  FILTER / SEARCH LOGS"
  if [[ ! -f "$LOG_FILE" ]]; then
    warn "No log file yet: $LOG_FILE"
    pause
    return
  fi
  printf "  ${CY}Search pattern:${N} "
  read -r pattern
  if [ -z "$pattern" ]; then
    warn "Pattern required."
  else
    blank
    grep -n --color=never -i "$pattern" "$LOG_FILE" || warn "No matches for: $pattern"
  fi
  pause
}

maint_import_reports() {
  section_header "SYSTEM & MAINTENANCE  //  RECENT IMPORT REPORTS"
  if [[ -f "$IMPORT_REPORT_FILE" ]]; then
    info "Last 30 entries from: $IMPORT_REPORT_FILE"
    blank
    tail -n 30 "$IMPORT_REPORT_FILE"
  else
    warn "No import report yet: $IMPORT_REPORT_FILE"
  fi
  pause
}

maint_scrub_junk() {
  section_header "SYSTEM & MAINTENANCE  //  SCRUB JUNK FILES"
  info "Targets: *.nfo  *.txt  *.sfv  *.nzb  *.url  *.lnk  *.DS_Store  Thumbs.db  *.jpg  *.jpeg  *.png  *sample*"
  info "Scans:   $TEMP_DIR   $FINISHED_DIR   $OUTPUT_BASE"
  blank

  local junk_patterns=('*.nfo' '*.txt' '*.sfv' '*.nzb' '*.url' '*.lnk' '*.DS_Store' 'Thumbs.db'
                       '*.jpg' '*.jpeg' '*.png' '*sample*')
  local base pat
  for base in "$TEMP_DIR" "$FINISHED_DIR" "$OUTPUT_BASE"; do
    [ -d "$base" ] || continue
    echo -e "  ${WH}Scanning: $base${N}"
    for pat in "${junk_patterns[@]}"; do
      find "$base" -type f -name "$pat" 2>/dev/null | while IFS= read -r f; do
        echo "    $f"
      done
    done
  done

  blank
  confirm "Delete all listed junk files?" || return
  blank
  for base in "$TEMP_DIR" "$FINISHED_DIR" "$OUTPUT_BASE"; do
    [ -d "$base" ] || continue
    for pat in "${junk_patterns[@]}"; do
      find "$base" -type f -name "$pat" -delete 2>/dev/null || true
    done
  done
  ok "Junk files removed."
  pause
}

maint_cleanup_preview() {
  section_header "SYSTEM & MAINTENANCE  //  CLEANUP PREVIEW (AGED FILES)"
  info "Candidate files in TEMP_DIR older than $CLEANUP_DAYS days:"
  blank
  find "$TEMP_DIR" -type f -mtime +"$CLEANUP_DAYS" 2>/dev/null || true
  blank
  confirm "Delete listed old files now?" || return
  find "$TEMP_DIR" -type f -mtime +"$CLEANUP_DAYS" -delete 2>/dev/null || true
  ok "Old files deleted from TEMP_DIR."
  pause
}

maint_wipe_history() {
  section_header "SYSTEM & MAINTENANCE  //  WIPE AMC HISTORY"
  warn "This clears FileBot's record of processed files"
  warn "Re-running AMC may duplicate already-moved files"
  blank
  confirm "Wipe AMC history?" || return
  blank
  filebot -script fn:cleaner 2>/dev/null \
    && ok "AMC history cleared" \
    || {
      info "Trying manual clear..."
      rm -f "$HOME/.filebot/history.xml" \
        && ok "history.xml removed" \
        || fail "Could not locate history file"
    }
  pause
}

maint_empty_finished() {
  section_header "SYSTEM & MAINTENANCE  //  EMPTY FINISHED/TEMP"
  warn "This permanently deletes contents of:"
  echo "    $FINISHED_DIR"
  echo "    $TEMP_DIR"
  blank
  confirm "Delete ALL files in finished and temp dirs?" || return
  blank

  local failed=0
  if [[ -d "$FINISHED_DIR" ]]; then
    rm -rf "${FINISHED_DIR:?}"/* 2>/dev/null || failed=1
  else
    warn "Finished dir not found: $FINISHED_DIR"
  fi
  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "${TEMP_DIR:?}"/* 2>/dev/null || failed=1
  else
    warn "Temp dir not found: $TEMP_DIR"
  fi

  [[ $failed -eq 0 ]] && ok "Finished/temp dirs emptied" || fail "Delete failed"
  pause
}

maint_mount_disk_checks() {
  section_header "SYSTEM & MAINTENANCE  //  MOUNT / PERMISSION / DISK CHECKS"
  local p
  for p in "$FINISHED_DIR" "$TEMP_DIR" "$WATCH_DIR" "$OUTPUT_BASE" "$MOVIES_DIR" "$SERIES_DIR"; do
    echo -e "  ${WH}$p${N}"
    if [ -d "$p" ]; then
      echo -e "    Exists:   ${GR}yes${N}"
      if [ -w "$p" ]; then
        echo -e "    Writable: ${GR}yes${N}"
      else
        echo -e "    Writable: ${RE}no${N}"
      fi
      df -h "$p" 2>/dev/null | awk 'NR>1 {printf "    Disk:     %s used of %s (%s free)\n", $3, $2, $4}'
    else
      echo -e "    Exists:   ${RE}no${N}"
    fi
    blank
  done
  pause
}

maint_find_duplicates() {
  section_header "SYSTEM & MAINTENANCE  //  DUPLICATE DETECTION"
  info "Checking for media files with identical size+name in MOVIES_DIR and SERIES_DIR"
  blank

  _get_size() {
    stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || echo 0
  }

  local root
  for root in "$MOVIES_DIR" "$SERIES_DIR"; do
    [ -d "$root" ] || continue
    echo -e "  ${WH}Checking: $root${N}"
    find "$root" -type f \( -name '*.mkv' -o -name '*.mp4' -o -name '*.avi' \) 2>/dev/null \
      | while IFS= read -r media_file; do
          local size
          size="$(_get_size "$media_file")"
          [ "${size:-0}" -gt 0 ] 2>/dev/null || continue
          printf '%s|%s|%s\n' "$size" "$(basename "$media_file")" "$media_file"
        done \
      | sort | awk -F'|' '
          { key = $1 "|" $2; count[key]++; paths[key] = paths[key] "    " $3 "\n" }
          END {
            for (k in count) {
              if (count[k] > 1) {
                split(k, m, "|")
                printf "  duplicate (%s bytes, %s):\n%s", m[1], m[2], paths[k]
              }
            }
          }
        '
  done
  pause
}

maint_storage_summary() {
  section_header "SYSTEM & MAINTENANCE  //  STORAGE SUMMARY"
  echo -e "  ${WH}Host paths:${N}"
  local p
  for p in "$FINISHED_DIR" "$TEMP_DIR" "$WATCH_DIR" "$OUTPUT_BASE" "$MOVIES_DIR" "$SERIES_DIR"; do
    if [ -d "$p" ]; then
      du -sh "$p" 2>/dev/null | awk -v path="$p" '{printf "    %-40s %s\n", path, $1}'
    else
      printf "    %-40s missing\n" "$p"
    fi
  done

  local containers
  containers="$(find_qbittorrent_containers)"
  if [ -n "$containers" ]; then
    blank
    echo -e "  ${WH}Docker-exposed mounts:${N}"
    local c
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      echo "  Container: $c"
      inspect_container_mounts "$c" | sed 's/^/    /'
    done <<< "$containers"
  fi
  pause
}

maint_plex_test() {
  section_header "SYSTEM & MAINTENANCE  //  PLEX CONNECTIVITY TEST"
  info "Testing: $PLEX_URL"
  blank
  if [ -n "$PLEX_TOKEN" ]; then
    if curl -fsS --max-time 10 -H "X-Plex-Token: $PLEX_TOKEN" "$PLEX_URL" >/dev/null 2>&1; then
      ok "Plex connectivity OK (with token)"
    else
      fail "Plex connectivity FAILED (with token)"
    fi
  else
    if curl -fsS --max-time 10 "$PLEX_URL" >/dev/null 2>&1; then
      ok "Plex connectivity OK (no token)"
    else
      fail "Plex connectivity FAILED — check PLEX_URL and PLEX_TOKEN"
    fi
  fi
  pause
}

maint_upgrade() {
  section_header "SYSTEM & MAINTENANCE  //  SYSTEM UPGRADE & RE-VERIFY DEPS"
  info "apt update / upgrade / autoremove + verify filebot + java"
  blank
  confirm "Continue?" || return
  blank
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get autoremove -y && sudo apt-get autoclean
  blank
  command -v filebot &>/dev/null \
    && ok "filebot: $(filebot --version 2>/dev/null | head -1)" \
    || fail "filebot not found"
  command -v java &>/dev/null \
    && ok "java: $(java -version 2>&1 | head -1)" \
    || fail "java not found"
  pause
}

# ════════════════════════════════════════════════════════════
#  ALERTS & TESTING
# ════════════════════════════════════════════════════════════

alerts_test_notifications() {
  section_header "ALERTS & TESTING  //  TEST NOTIFICATIONS"
  info "Sends a test ping via Pushover"
  blank
  [[ -z "$PUSHOVER_USER" || -z "$PUSHOVER_TOKEN" ]] \
    && warn "Pushover credentials not set — skipping" \
    || {
      confirm "Send Pushover test?" && \
        curl -s \
          --form-string "token=$PUSHOVER_TOKEN" \
          --form-string "user=$PUSHOVER_USER" \
          --form-string "message=FileBot Manager: test notification" \
          https://api.pushover.net/1/messages.json > /dev/null \
        && ok "Pushover sent" || fail "Pushover failed"
    }
  blank
  pause
}

alerts_test_cycle() {
  section_header "ALERTS & TESTING  //  RUN TEST CYCLE"
  _validate || return
  warn "Dry-run + notification test combined"
  blank
  confirm "Continue?" || return
  blank
  _run_filebot "--action test" "$FINISHED_DIR"
  local c=$?
  blank
  [[ $c -eq 0 ]] && ok "Test cycle complete" || fail "Test cycle exited $c"
  pause
}

alerts_backup() {
  section_header "ALERTS & TESTING  //  TRIGGER CONFIGURATION BACKUP"
  local ts
  ts=$(date +%F_%H-%M-%S)
  local dest="$SCRIPT_DIR/.env.backup.$ts"
  if [[ ! -f "$ENV_FILE" ]]; then
    fail "No .env found — save config in Setup first"
    pause
    return
  fi
  info "Destination: $dest"
  blank
  confirm "Back up now?" || return
  cp "$ENV_FILE" "$dest" && chmod 600 "$dest" \
    && ok "Backed up → $dest" || fail "Backup failed"
  pause
}

alerts_bbb_qbittorrent() {
  section_header "ALERTS & TESTING  //  BBB TEST VIA QBITTORRENT"
  local local_detected
  local_detected="$(detect_qbittorrent_local)"
  if [ -n "$local_detected" ]; then
    ok "Local qBittorrent: $local_detected"
  else
    warn "No local qBittorrent process detected."
  fi
  [ -n "$QBITTORRENT_CONTAINER" ] && info "Configured container: $QBITTORRENT_CONTAINER"
  blank
  info "Manual steps:"
  echo "  1) Add Big Buck Bunny torrent to qBittorrent"
  echo "  2) Let it complete in FINISHED_DIR"
  echo "  3) This script processes the completed item"
  blank
  read -r -p "  Enter completed path to process now (blank to skip): " completed_path
  if [ -n "$completed_path" ]; then
    normalize_and_run "$completed_path"
  fi
  pause
}

alerts_bbb_transmission() {
  section_header "ALERTS & TESTING  //  BBB TEST VIA TRANSMISSION-CLI"
  if ! command -v transmission-cli >/dev/null 2>&1; then
    fail "transmission-cli is not installed."
    pause
    return
  fi

  local target_dir="$TEMP_DIR/bbb-test"
  mkdir -p "$target_dir"

  info "Downloading Big Buck Bunny test torrent via transmission-cli..."
  info "URL: $BBB_TORRENT_URL"
  info "Target: $target_dir"
  blank
  if transmission-cli "$BBB_TORRENT_URL" -w "$target_dir"; then
    ok "Download complete; running FileBot against test directory."
    normalize_and_run "$target_dir"
  else
    fail "transmission-cli download failed."
  fi
  blank
  confirm "Delete BBB test files at $target_dir?" && rm -rf "$target_dir" && ok "Removed test files."
  pause
}

# ════════════════════════════════════════════════════════════
#  NON-INTERACTIVE AUTO MODE
# ════════════════════════════════════════════════════════════

run_auto_filebot() {
  local location="${1:-}"
  local name_arg="${2:-}"
  local file_arg="${3:-}"

  local selected_path=""
  if [ -n "$location" ] && [ "$location" != "%L" ]; then
    selected_path="$location"
  elif [ -n "$file_arg" ] && [ "$file_arg" != "%F" ]; then
    selected_path="$file_arg"
  elif [ -n "$name_arg" ] && [ "$name_arg" != "%N" ]; then
    selected_path="$name_arg"
  else
    selected_path="$FINISHED_DIR"
  fi

  selected_path="$(normalize_path "$selected_path")"
  log_msg "INFO" "auto-filebot: processing completed item: $selected_path"
  normalize_and_run "$selected_path"
}

# ════════════════════════════════════════════════════════════
#  MAIN MENU
# ════════════════════════════════════════════════════════════

main_menu() {
  while true; do
    print_header

    echo -e "  ${WH}SETUP & CONFIGURATION${N}"
    echo -e "  ${CY}[01]${N} ${GR}Update Environment & Credentials${N}"
    echo -e "  ${CY}[02]${N} ${GR}Configure Directories${N}"
    echo -e "  ${CY}[03]${N} ${GR}Configure Processing Defaults${N}"
    echo -e "  ${CY}[04]${N} ${GR}Show Dynamic AMC / Hook Commands${N}"
    echo -e "  ${CY}[05]${N} ${GR}Install / Re-verify Dependencies${N}"
    echo -e "  ${CY}[06]${N} ${GR}First-time Discovery & Path Mapping${N}"
    echo -e "  ${CY}[07]${N} ${GR}Discover qBittorrent (native + Docker)${N}"
    echo -e "  ${CY}[08]${N} ${GR}Install / Update qBittorrent Completion Hook${N}"
    echo -e "  ${CY}[09]${N} ${GR}Verify qBittorrent Hook${N}"
    echo -e "  ${CY}[10]${N} ${GR}qBittorrent Optimization Assistance${N}"
    blank

    echo -e "  ${WH}CORE PROCESSING${N}"
    echo -e "  ${CY}[11]${N} ${GR}Run Move (Finished)${N}"
    echo -e "  ${CY}[12]${N} ${GR}Run Move (Temp)${N}"
    echo -e "  ${CY}[13]${N} ${GR}Forced Run (Ignore History)${N}"
    echo -e "  ${CY}[14]${N} ${GR}Simulation Mode (Dry Run)${N}"
    blank

    echo -e "  ${WH}SYSTEM & MAINTENANCE${N}"
    echo -e "  ${CY}[15]${N} ${GR}View Logs${N}"
    echo -e "  ${CY}[16]${N} ${GR}Filter / Search Logs${N}"
    echo -e "  ${CY}[17]${N} ${GR}Recent Import Reports${N}"
    echo -e "  ${CY}[18]${N} ${GR}Scrub Junk Files${N}"
    echo -e "  ${CY}[19]${N} ${GR}Cleanup Preview (aged files)${N}"
    echo -e "  ${CY}[20]${N} ${GR}Wipe AMC History${N}"
    echo -e "  ${CY}[21]${N} ${GR}Empty Finished / Temp${N}"
    echo -e "  ${CY}[22]${N} ${GR}Mount / Permission / Disk Checks${N}"
    echo -e "  ${CY}[23]${N} ${GR}Duplicate Detection${N}"
    echo -e "  ${CY}[24]${N} ${GR}Storage Summary${N}"
    echo -e "  ${CY}[25]${N} ${GR}Plex Connectivity Test${N}"
    echo -e "  ${CY}[26]${N} ${YE}SYSTEM UPGRADE & RE-VERIFY DEPS${N}"
    blank

    echo -e "  ${WH}ALERTS & TESTING${N}"
    echo -e "  ${CY}[27]${N} ${GR}Test Notifications${N}"
    echo -e "  ${CY}[28]${N} ${GR}Run Test Cycle${N}"
    echo -e "  ${CY}[29]${N} ${GR}Trigger Configuration Backup${N}"
    echo -e "  ${CY}[30]${N} ${GR}BBB Test via qBittorrent${N}"
    echo -e "  ${CY}[31]${N} ${GR}BBB Test via transmission-cli${N}"
    echo -e "  ${CY}[32]${N} ${GR}View Integration Summary${N}"
    blank

    echo -e "  ${WH}SYSTEM${N}"
    echo -e "  ${CY}[00]${N} ${RE}TERMINATE SESSION${N}"
    blank
    divider
    printf "  ${WH}SELECT OPTION:${N} "
    read -r choice

    case "$choice" in
      01|1)  setup_configure_creds ;;
      02|2)  setup_configure_dirs ;;
      03|3)  setup_configure_processing ;;
      04|4)  setup_show_command ;;
      05|5)  setup_install_deps ;;
      06|6)  setup_first_time_discovery ;;
      07|7)  setup_qb_discovery ;;
      08|8)  setup_install_hook ;;
      09|9)  setup_verify_hook ;;
      10)    setup_qb_optimization ;;
      11)    core_run_finished ;;
      12)    core_run_temp ;;
      13)    core_run_force ;;
      14)    core_run_dry ;;
      15)    maint_view_logs ;;
      16)    maint_search_logs ;;
      17)    maint_import_reports ;;
      18)    maint_scrub_junk ;;
      19)    maint_cleanup_preview ;;
      20)    maint_wipe_history ;;
      21)    maint_empty_finished ;;
      22)    maint_mount_disk_checks ;;
      23)    maint_find_duplicates ;;
      24)    maint_storage_summary ;;
      25)    maint_plex_test ;;
      26)    maint_upgrade ;;
      27)    alerts_test_notifications ;;
      28)    alerts_test_cycle ;;
      29)    alerts_backup ;;
      30)    alerts_bbb_qbittorrent ;;
      31)    alerts_bbb_transmission ;;
      32)    show_integration_summary ;;
      00|0)  break ;;
      *)     warn "Invalid selection"; pause ;;
    esac
  done

  clear
  echo -e "${BL}$(printf '═%.0s' {1..70})${N}"
  echo -e "  ${DI}SESSION TERMINATED${N}"
  echo -e "${BL}$(printf '═%.0s' {1..70})${N}"
  echo ""
}

# ════════════════════════════════════════════════════════════
#  ENTRY POINT
# ════════════════════════════════════════════════════════════

resolve_script_path
load_config
ensure_dirs

if [[ "${1:-}" = "--auto-filebot" ]]; then
  shift
  run_auto_filebot "${1:-}" "${2:-}" "${3:-}"
  exit $?
fi

main_menu
