#!/usr/bin/env bash

set -u

SCRIPT_PATH=""
SCRIPT_DIR=""
APP_NAME="SnorlaxBot"
APP_DESC="FileBot Manager"
CONFIG_FILE=""
LOG_DIR=""
LOG_FILE=""
IMPORT_REPORT_FILE=""

FINISHED_DIR=""
TEMP_DIR=""
WATCH_DIR=""
OUTPUT_BASE=""
MOVIES_DIR=""
SERIES_DIR=""
QB_CONFIG_PATH=""
QBITTORRENT_VARIANT=""
QBITTORRENT_MODE=""
QBITTORRENT_CONTAINER=""
QBITTORRENT_COMPLETION_HOOK=""
DOCKER_COMPOSE_FILE=""
API_USERNAME=""
API_PASSWORD=""
API_TOKEN=""
PLEX_URL="http://localhost:32400/identity"
PLEX_TOKEN=""
LAST_DISCOVERED_PATHS=""

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
  CONFIG_FILE="$SCRIPT_DIR/.snorlaxbot.conf"
  LOG_DIR="$SCRIPT_DIR/logs"
  LOG_FILE="$LOG_DIR/snorlaxbot.log"
  IMPORT_REPORT_FILE="$LOG_DIR/import-report.log"
}

log_msg() {
  mkdir -p "$LOG_DIR"
  local level="$1"
  shift
  local message="$*"
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" | tee -a "$LOG_FILE" >/dev/null
}

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

escape_for_conf() {
  printf '%q' "$1"
}

load_defaults() {
  FINISHED_DIR="$HOME/Downloads/finished"
  TEMP_DIR="$HOME/Downloads/incomplete"
  WATCH_DIR="$HOME/Downloads/watch"
  OUTPUT_BASE="$HOME/Media"
  MOVIES_DIR="$OUTPUT_BASE/Movies"
  SERIES_DIR="$OUTPUT_BASE/TV"
  QB_CONFIG_PATH="$HOME/.config/qBittorrent/qBittorrent.conf"
  QBITTORRENT_VARIANT=""
  QBITTORRENT_MODE=""
  QBITTORRENT_CONTAINER=""
  QBITTORRENT_COMPLETION_HOOK=""
  DOCKER_COMPOSE_FILE=""
  API_USERNAME=""
  API_PASSWORD=""
  API_TOKEN=""
  PLEX_URL="http://localhost:32400/identity"
  PLEX_TOKEN=""
  LAST_DISCOVERED_PATHS=""
}

save_config() {
  cat > "$CONFIG_FILE" <<CFG
FINISHED_DIR=$(escape_for_conf "$FINISHED_DIR")
TEMP_DIR=$(escape_for_conf "$TEMP_DIR")
WATCH_DIR=$(escape_for_conf "$WATCH_DIR")
OUTPUT_BASE=$(escape_for_conf "$OUTPUT_BASE")
MOVIES_DIR=$(escape_for_conf "$MOVIES_DIR")
SERIES_DIR=$(escape_for_conf "$SERIES_DIR")
QB_CONFIG_PATH=$(escape_for_conf "$QB_CONFIG_PATH")
QBITTORRENT_VARIANT=$(escape_for_conf "$QBITTORRENT_VARIANT")
QBITTORRENT_MODE=$(escape_for_conf "$QBITTORRENT_MODE")
QBITTORRENT_CONTAINER=$(escape_for_conf "$QBITTORRENT_CONTAINER")
QBITTORRENT_COMPLETION_HOOK=$(escape_for_conf "$QBITTORRENT_COMPLETION_HOOK")
DOCKER_COMPOSE_FILE=$(escape_for_conf "$DOCKER_COMPOSE_FILE")
API_USERNAME=$(escape_for_conf "$API_USERNAME")
API_PASSWORD=$(escape_for_conf "$API_PASSWORD")
API_TOKEN=$(escape_for_conf "$API_TOKEN")
PLEX_URL=$(escape_for_conf "$PLEX_URL")
PLEX_TOKEN=$(escape_for_conf "$PLEX_TOKEN")
LAST_DISCOVERED_PATHS=$(escape_for_conf "$LAST_DISCOVERED_PATHS")
CFG
  log_msg "INFO" "Configuration saved to $CONFIG_FILE"
}

load_config() {
  load_defaults
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
  mkdir -p "$LOG_DIR"
}

snorlax_ascii() {
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
}

print_title_area() {
  clear
  snorlax_ascii
  cat <<'TITLE'
=========================================================
                     FILEBOT AUTOMATION
=========================================================
TITLE
  echo "$APP_NAME — $APP_DESC"
  echo "Script: $SCRIPT_PATH"
  echo
}

print_section_header() {
  local section="$1"
  print_title_area
  echo "-------------------- $section --------------------"
}

pause_prompt() {
  echo
  read -r -p "Press Enter to continue..." _
}

prompt_with_default() {
  local label="$1"
  local current="$2"
  local input
  read -r -p "$label [$current]: " input
  if [ -n "$input" ]; then
    echo "$input"
  else
    echo "$current"
  fi
}

normalize_path() {
  local raw_path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath -m "$raw_path"
  elif [ -d "$raw_path" ]; then
    (cd "$raw_path" >/dev/null 2>&1 && pwd)
  else
    local base
    base="$(basename "$raw_path")"
    local dir
    dir="$(dirname "$raw_path")"
    (cd "$dir" >/dev/null 2>&1 && printf '%s/%s\n' "$(pwd)" "$base")
  fi
}

build_qb_hook_command() {
  printf '/bin/bash "%s" --auto-filebot "%%L" "%%N" "%%F"' "$SCRIPT_PATH"
}

build_amc_command() {
  local source_path="$1"
  printf 'filebot -script fn:amc --output "%s" --action duplicate --conflict auto -non-strict "%s" --def movieFormat="{n} ({y})" seriesFormat="{n}/Season {s}/{n} - {s00e00} - {t}"' "$OUTPUT_BASE" "$source_path"
}

show_integration_summary() {
  print_section_header "Current Integration Summary"
  cat <<SUMMARY
API Username: ${API_USERNAME:-<unset>}
API Password: $(mask_secret "$API_PASSWORD")
API Token:    $(mask_secret "$API_TOKEN")
Plex URL:     ${PLEX_URL:-<unset>}
Plex Token:   $(mask_secret "$PLEX_TOKEN")

Directories:
  FINISHED_DIR: $FINISHED_DIR
  TEMP_DIR:     $TEMP_DIR
  WATCH_DIR:    $WATCH_DIR
  OUTPUT_BASE:  $OUTPUT_BASE
  MOVIES_DIR:   $MOVIES_DIR
  SERIES_DIR:   $SERIES_DIR

qBittorrent:
  Variant:      ${QBITTORRENT_VARIANT:-<auto>}
  Mode:         ${QBITTORRENT_MODE:-<auto>}
  Container:    ${QBITTORRENT_CONTAINER:-<none>}
  Config path:  ${QB_CONFIG_PATH:-<unset>}
  Compose file: ${DOCKER_COMPOSE_FILE:-<unset>}

Expected qBittorrent external program hook:
  $(build_qb_hook_command)

Current AMC command for FINISHED_DIR:
  $(build_amc_command "$FINISHED_DIR")
SUMMARY
}

check_one_dependency() {
  local command_name="$1"
  local label="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    printf '[OK]   %s (%s)\n' "$label" "$command_name"
    return 0
  fi
  printf '[MISS] %s (%s)\n' "$label" "$command_name"
  return 1
}

check_dependencies() {
  print_section_header "SETUP: Dependency and Environment Checks"
  local missing=0
  check_one_dependency filebot "FileBot" || missing=$((missing + 1))
  check_one_dependency java "Java" || missing=$((missing + 1))
  check_one_dependency curl "curl" || missing=$((missing + 1))
  check_one_dependency docker "Docker" || missing=$((missing + 1))
  if check_one_dependency docker-compose "docker-compose"; then
    :
  elif check_one_dependency docker "docker compose (via docker)"; then
    if docker compose version >/dev/null 2>&1; then
      echo "[OK]   Docker Compose plugin (docker compose)"
    else
      echo "[MISS] Docker Compose plugin not available"
      missing=$((missing + 1))
    fi
  else
    missing=$((missing + 1))
  fi
  check_one_dependency qbittorrent "qBittorrent GUI" || true
  check_one_dependency qbittorrent-nox "qBittorrent Nox" || true
  check_one_dependency transmission-cli "transmission-cli" || missing=$((missing + 1))

  echo
  echo "Common shell utilities:"
  local util
  local util_missing=0
  for util in bash awk sed grep find sort cut tr head tail xargs df du stat chmod mkdir realpath; do
    if command -v "$util" >/dev/null 2>&1; then
      printf '  [OK]   %s\n' "$util"
    else
      printf '  [MISS] %s\n' "$util"
      util_missing=$((util_missing + 1))
    fi
  done
  missing=$((missing + util_missing))

  echo
  if [ "$missing" -eq 0 ]; then
    echo "Environment looks ready."
  else
    echo "Missing checks: $missing (review above)."
    echo "Install guidance (Debian/Ubuntu):"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y filebot default-jre curl docker.io docker-compose qbittorrent qbittorrent-nox transmission-cli"
  fi
}

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
  docker ps --format '{{.Names}}|{{.Image}}' 2>/dev/null | awk -F'|' 'tolower($0) ~ /qbittorrent|qbit/ {print $1}'
}

inspect_container_mounts() {
  local container_name="$1"
  if ! command -v docker >/dev/null 2>&1; then
    return 0
  fi
  docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' "$container_name" 2>/dev/null
}

discover_likely_paths() {
  local discovered_finished=""
  local discovered_temp=""
  local discovered_watch=""
  local discovered_config=""

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
  [ -n "$discovered_temp" ] && TEMP_DIR="$discovered_temp"
  [ -n "$discovered_watch" ] && WATCH_DIR="$discovered_watch"
  if [ -n "$discovered_config" ]; then
    QB_CONFIG_PATH="$discovered_config/qBittorrent/qBittorrent.conf"
  fi

  LAST_DISCOVERED_PATHS="finished=$discovered_finished;temp=$discovered_temp;watch=$discovered_watch;config=$discovered_config"
}

first_setup_flow() {
  print_section_header "SETUP: First-time discovery and mapping"
  discover_likely_paths

  echo "Discovered hints: ${LAST_DISCOVERED_PATHS:-none}"
  echo

  FINISHED_DIR="$(prompt_with_default "FINISHED_DIR" "$FINISHED_DIR")"
  TEMP_DIR="$(prompt_with_default "TEMP_DIR" "$TEMP_DIR")"
  WATCH_DIR="$(prompt_with_default "WATCH_DIR" "$WATCH_DIR")"
  OUTPUT_BASE="$(prompt_with_default "OUTPUT_BASE" "$OUTPUT_BASE")"
  MOVIES_DIR="$(prompt_with_default "MOVIES_DIR" "$MOVIES_DIR")"
  SERIES_DIR="$(prompt_with_default "SERIES_DIR" "$SERIES_DIR")"

  local local_detected
  local_detected="$(detect_qbittorrent_local)"
  if [ -n "$local_detected" ]; then
    QBITTORRENT_MODE="native"
    QBITTORRENT_VARIANT="$local_detected"
  fi

  local first_container
  first_container="$(find_qbittorrent_containers | head -n 1)"
  if [ -n "$first_container" ]; then
    QBITTORRENT_MODE="docker"
    QBITTORRENT_CONTAINER="$first_container"
  fi

  QB_CONFIG_PATH="$(prompt_with_default "qBittorrent config path" "$QB_CONFIG_PATH")"
  QBITTORRENT_COMPLETION_HOOK="$(build_qb_hook_command)"
  save_config
  show_integration_summary
  pause_prompt
}

configure_api_credentials() {
  print_section_header "CONFIGURATION: API Credentials"
  API_USERNAME="$(prompt_with_default "API username" "$API_USERNAME")"
  read -r -p "API password [hidden, leave blank to keep current]: " -s new_password
  echo
  if [ -n "$new_password" ]; then
    API_PASSWORD="$new_password"
  fi
  read -r -p "API token [hidden, leave blank to keep current]: " -s new_token
  echo
  if [ -n "$new_token" ]; then
    API_TOKEN="$new_token"
  fi
  read -r -p "Plex token [hidden, leave blank to keep current]: " -s new_plex
  echo
  if [ -n "$new_plex" ]; then
    PLEX_TOKEN="$new_plex"
  fi
  PLEX_URL="$(prompt_with_default "Plex identity URL" "$PLEX_URL")"
  save_config
  show_integration_summary
  pause_prompt
}

configure_directories() {
  print_section_header "CONFIGURATION: Directory Paths"
  FINISHED_DIR="$(prompt_with_default "FINISHED_DIR" "$FINISHED_DIR")"
  TEMP_DIR="$(prompt_with_default "TEMP_DIR" "$TEMP_DIR")"
  WATCH_DIR="$(prompt_with_default "WATCH_DIR" "$WATCH_DIR")"
  OUTPUT_BASE="$(prompt_with_default "OUTPUT_BASE" "$OUTPUT_BASE")"
  MOVIES_DIR="$(prompt_with_default "MOVIES_DIR" "$MOVIES_DIR")"
  SERIES_DIR="$(prompt_with_default "SERIES_DIR" "$SERIES_DIR")"
  save_config
  show_integration_summary
  pause_prompt
}

display_qb_discovery() {
  print_section_header "SETUP: qBittorrent Native + Docker Discovery"
  local local_detected
  local_detected="$(detect_qbittorrent_local)"
  if [ -n "$local_detected" ]; then
    echo "Local qBittorrent detected: $local_detected"
  else
    echo "Local qBittorrent binaries/processes not detected."
  fi

  local containers
  containers="$(find_qbittorrent_containers)"
  if [ -n "$containers" ]; then
    echo
    echo "Likely qBittorrent Docker containers:"
    echo "$containers"
    echo
    local c
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      echo "Mounts for container $c:"
      inspect_container_mounts "$c" | sed 's/^/  /'
    done <<< "$containers"
  else
    echo
    echo "No likely qBittorrent Docker containers detected."
  fi

  echo
  discover_likely_paths
  echo "Path hints updated: ${LAST_DISCOVERED_PATHS:-none}"
  save_config
  pause_prompt
}

install_hook_guidance() {
  print_section_header "SETUP: Install qBittorrent Completion Hook"
  local cmd
  cmd="$(build_qb_hook_command)"

  echo "Use this command in qBittorrent -> Downloads -> Run external program on torrent completion:"
  echo "  $cmd"
  echo
  QBITTORRENT_COMPLETION_HOOK="$cmd"

  if [ -n "$QB_CONFIG_PATH" ] && [ -f "$QB_CONFIG_PATH" ]; then
    echo "Detected config file: $QB_CONFIG_PATH"
    if grep -Fq "$cmd" "$QB_CONFIG_PATH"; then
      echo "Hook already configured with current script path."
    else
      echo "Hook not found in config."
      read -r -p "Attempt safe in-file update for Program line? [y/N]: " answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        cp "$QB_CONFIG_PATH" "$QB_CONFIG_PATH.bak.$(date +%s)"
        if grep -q '^Downloads\\Program=' "$QB_CONFIG_PATH"; then
          sed -i "s#^Downloads\\Program=.*#Downloads\\Program=$cmd#" "$QB_CONFIG_PATH"
        else
          printf '\nDownloads\\Program=%s\n' "$cmd" >> "$QB_CONFIG_PATH"
        fi
        if grep -q '^Downloads\\RunExternalProgram=' "$QB_CONFIG_PATH"; then
          sed -i 's/^Downloads\\RunExternalProgram=.*/Downloads\\RunExternalProgram=true/' "$QB_CONFIG_PATH"
        else
          printf 'Downloads\\RunExternalProgram=true\n' >> "$QB_CONFIG_PATH"
        fi
        echo "Updated config. Restart qBittorrent to apply."
      fi
    fi
  else
    echo "qBittorrent config not found at QB_CONFIG_PATH. Manual update may be required."
  fi

  if [ -n "$DOCKER_COMPOSE_FILE" ] && [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo
    echo "Compose file provided: $DOCKER_COMPOSE_FILE"
    if rg --version >/dev/null 2>&1; then
      rg -n "qbit|qbittorrent|volumes|downloads|watch|config" "$DOCKER_COMPOSE_FILE" || true
    else
      grep -nE "qbit|qbittorrent|volumes|downloads|watch|config" "$DOCKER_COMPOSE_FILE" || true
    fi
  fi

  save_config
  show_integration_summary
  pause_prompt
}

verify_hook_setup() {
  print_section_header "SETUP: Verify qBittorrent Hook"
  local expected
  expected="$(build_qb_hook_command)"
  echo "Expected hook command:"
  echo "  $expected"
  echo

  local verified=0
  if [ -n "$QB_CONFIG_PATH" ] && [ -f "$QB_CONFIG_PATH" ]; then
    echo "Inspecting: $QB_CONFIG_PATH"
    local current
    current="$(grep '^Downloads\\Program=' "$QB_CONFIG_PATH" | head -n 1 | cut -d'=' -f2-)"
    echo "Current configured Program: ${current:-<unset>}"
    if [ "$current" = "$expected" ]; then
      echo "[OK] Script path in qBittorrent hook matches current script path."
      verified=1
    else
      echo "[WARN] Script path mismatch."
    fi
  else
    echo "qBittorrent config file unavailable for direct verification."
  fi

  if [ "$verified" -eq 0 ]; then
    echo
    echo "Fallback guidance:"
    echo "1) Open qBittorrent settings"
    echo "2) Set completion hook to exactly:"
    echo "   $expected"
    echo "3) Save and re-check from this menu"
  fi

  pause_prompt
}

show_qb_optimization_help() {
  print_section_header "SETUP: qBittorrent Optimization Assistance"
  echo "Path consistency checks:"
  for path_var in FINISHED_DIR TEMP_DIR WATCH_DIR OUTPUT_BASE MOVIES_DIR SERIES_DIR; do
    local path_value=""
    # shellcheck disable=SC2086
    path_value="$(eval echo \$$path_var)"
    if [ -d "$path_value" ]; then
      echo "  [OK] $path_var exists: $path_value"
    else
      echo "  [WARN] $path_var missing: $path_value"
    fi
  done

  echo
  local containers
  containers="$(find_qbittorrent_containers)"
  if [ -n "$containers" ]; then
    echo "Docker container mount mapping suggestions:"
    local c
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      echo "- $c"
      inspect_container_mounts "$c" | sed 's/^/    /'
    done <<< "$containers"
    echo "Suggestion: ensure host FINISHED_DIR/TEMP_DIR paths map to the same paths FileBot can access."
  else
    echo "No qBittorrent Docker containers detected to inspect."
  fi

  if [ -n "$DOCKER_COMPOSE_FILE" ] && [ -f "$DOCKER_COMPOSE_FILE" ]; then
    echo
    echo "Compose inspection hints from: $DOCKER_COMPOSE_FILE"
    grep -nE 'qbit|qbittorrent|volume|download|watch|config' "$DOCKER_COMPOSE_FILE" || true
  fi

  pause_prompt
}

ensure_dirs() {
  mkdir -p "$FINISHED_DIR" "$TEMP_DIR" "$WATCH_DIR" "$OUTPUT_BASE" "$MOVIES_DIR" "$SERIES_DIR" "$LOG_DIR"
}

run_filebot_on_path() {
  local target_path="$1"
  local mode="$2"
  local normalized
  normalized="$(normalize_path "$target_path")"

  if [ ! -e "$normalized" ]; then
    echo "Target does not exist: $normalized"
    log_msg "ERROR" "Missing target path for processing: $normalized"
    return 1
  fi

  local amc_cmd
  amc_cmd="$(build_amc_command "$normalized")"

  echo "Running FileBot mode=$mode path=$normalized"
  log_msg "INFO" "Running FileBot mode=$mode path=$normalized"

  if [ "$mode" = "dry" ]; then
    amc_cmd="$amc_cmd --def ut_kind=multi --action test"
  elif [ "$mode" = "force" ]; then
    amc_cmd="$amc_cmd --conflict override"
  fi

  echo "Command:"
  echo "  $amc_cmd"

  if command -v filebot >/dev/null 2>&1; then
    if eval "$amc_cmd"; then
      log_msg "INFO" "FILEBOT_RESULT success path=$normalized mode=$mode"
      printf '%s | success | %s | %s\n' "$(date '+%F %T')" "$mode" "$normalized" >> "$IMPORT_REPORT_FILE"
      echo "FileBot completed successfully."
      return 0
    fi
    log_msg "ERROR" "FILEBOT_RESULT failure path=$normalized mode=$mode"
    printf '%s | failure | %s | %s\n' "$(date '+%F %T')" "$mode" "$normalized" >> "$IMPORT_REPORT_FILE"
    echo "FileBot failed."
    return 1
  fi

  echo "FileBot is not installed."
  log_msg "ERROR" "filebot binary missing"
  return 1
}

run_filebot_finished() {
  print_section_header "Processing: Run FileBot (Finished)"
  run_filebot_on_path "$FINISHED_DIR" "normal"
  pause_prompt
}

run_filebot_temp() {
  print_section_header "Processing: Run FileBot (Temp)"
  run_filebot_on_path "$TEMP_DIR" "normal"
  pause_prompt
}

run_filebot_custom() {
  print_section_header "Processing: Custom Path"
  read -r -p "Enter path to process: " custom_path
  [ -z "$custom_path" ] && custom_path="$FINISHED_DIR"
  run_filebot_on_path "$custom_path" "normal"
  pause_prompt
}

run_filebot_force() {
  print_section_header "Processing: Forced Run"
  read -r -p "Enter path to force process [$FINISHED_DIR]: " custom_path
  [ -z "$custom_path" ] && custom_path="$FINISHED_DIR"
  run_filebot_on_path "$custom_path" "force"
  pause_prompt
}

run_filebot_dry() {
  print_section_header "Processing: Dry Run"
  read -r -p "Enter path to dry-run [$FINISHED_DIR]: " custom_path
  [ -z "$custom_path" ] && custom_path="$FINISHED_DIR"
  run_filebot_on_path "$custom_path" "dry"
  echo "Dry-run summary (recent):"
  tail -n 5 "$IMPORT_REPORT_FILE" 2>/dev/null || true
  pause_prompt
}

bbb_test_qbittorrent() {
  print_section_header "Testing: BBB via qBittorrent"
  local local_detected
  local_detected="$(detect_qbittorrent_local)"
  if [ -n "$local_detected" ]; then
    echo "Detected local variant(s): $local_detected"
  else
    echo "No local qBittorrent process detected."
  fi

  if [ -n "$QBITTORRENT_CONTAINER" ]; then
    echo "Configured container: $QBITTORRENT_CONTAINER"
  fi

  echo
  echo "Manual helper steps:"
  echo "1) Add Big Buck Bunny torrent in qBittorrent"
  echo "2) Ensure completed content lands in FINISHED_DIR"
  echo "3) This script can process that completed item"
  read -r -p "Enter completed path to process now (blank to skip): " completed_path
  if [ -n "$completed_path" ]; then
    run_filebot_on_path "$completed_path" "normal"
  fi
  pause_prompt
}

bbb_test_transmission_cli() {
  print_section_header "Testing: BBB via transmission-cli"
  if ! command -v transmission-cli >/dev/null 2>&1; then
    echo "transmission-cli is not installed."
    pause_prompt
    return
  fi

  local torrent_url="https://webtorrent.io/torrents/big-buck-bunny.torrent"
  local target_dir="$TEMP_DIR/bbb-test"
  mkdir -p "$target_dir"

  echo "Downloading Big Buck Bunny test torrent via transmission-cli..."
  echo "URL: $torrent_url"
  echo "Target: $target_dir"
  if transmission-cli "$torrent_url" -w "$target_dir"; then
    echo "Download complete; running FileBot against test directory."
    run_filebot_on_path "$target_dir" "normal"
  else
    echo "transmission-cli download failed."
  fi

  read -r -p "Delete BBB test files at $target_dir ? [y/N]: " cleanup
  if [[ "$cleanup" =~ ^[Yy]$ ]]; then
    rm -rf "$target_dir"
    echo "Removed test files."
  fi
  pause_prompt
}

show_logs() {
  print_section_header "Maintenance: View Logs"
  if [ ! -f "$LOG_FILE" ]; then
    echo "No log file yet: $LOG_FILE"
  else
    tail -n 100 "$LOG_FILE"
  fi
  pause_prompt
}

search_logs() {
  print_section_header "Maintenance: Filter/Search Logs"
  if [ ! -f "$LOG_FILE" ]; then
    echo "No log file yet."
    pause_prompt
    return
  fi
  read -r -p "Search pattern: " pattern
  if [ -z "$pattern" ]; then
    echo "Pattern is required."
  else
    grep -n --color=never -i "$pattern" "$LOG_FILE" || true
  fi
  pause_prompt
}

show_recent_import_reports() {
  print_section_header "Maintenance: Recent Import Reports"
  if [ -f "$IMPORT_REPORT_FILE" ]; then
    tail -n 30 "$IMPORT_REPORT_FILE"
  else
    echo "No import report yet."
  fi
  pause_prompt
}

cleanup_preview() {
  print_section_header "Maintenance: Cleanup Preview"
  echo "Preview (no deletion yet):"
  echo "Candidate files in TEMP_DIR older than 7 days:"
  find "$TEMP_DIR" -type f -mtime +7 2>/dev/null | head -n 50
  read -r -p "Delete listed old files now? [y/N]: " choice
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    find "$TEMP_DIR" -type f -mtime +7 -delete 2>/dev/null
    echo "Old files deleted from TEMP_DIR."
  fi
  pause_prompt
}

scrub_junk_files() {
  print_section_header "Maintenance: Junk Scrubber"
  local junk_patterns=('*.nfo' '*.txt' '*.sfv' '*.url' '*.lnk' '*.DS_Store' 'Thumbs.db')
  local base
  for base in "$TEMP_DIR" "$FINISHED_DIR"; do
    [ -d "$base" ] || continue
    echo "Scanning $base"
    local pattern
    for pattern in "${junk_patterns[@]}"; do
      find "$base" -type f -name "$pattern" 2>/dev/null
    done
  done
  read -r -p "Delete listed junk files? [y/N]: " do_delete
  if [[ "$do_delete" =~ ^[Yy]$ ]]; then
    for base in "$TEMP_DIR" "$FINISHED_DIR"; do
      [ -d "$base" ] || continue
      local pattern
      for pattern in "${junk_patterns[@]}"; do
        find "$base" -type f -name "$pattern" -delete 2>/dev/null
      done
    done
    echo "Junk files removed."
  fi
  pause_prompt
}

check_mount_permissions_disk() {
  print_section_header "Maintenance: Mount / Permission / Disk Checks"
  local p
  for p in "$FINISHED_DIR" "$TEMP_DIR" "$WATCH_DIR" "$OUTPUT_BASE"; do
    echo "Path: $p"
    if [ -d "$p" ]; then
      echo "  Exists: yes"
      if [ -w "$p" ]; then
        echo "  Writable: yes"
      else
        echo "  Writable: no"
      fi
      df -h "$p" | tail -n +1
    else
      echo "  Exists: no"
    fi
    echo
  done
  pause_prompt
}

find_duplicates() {
  print_section_header "Maintenance: Duplicate Detection"
  local root
  for root in "$MOVIES_DIR" "$SERIES_DIR"; do
    [ -d "$root" ] || continue
    echo "Checking $root"
    find "$root" -type f \( -name '*.mkv' -o -name '*.mp4' -o -name '*.avi' \) -printf '%f\n' 2>/dev/null | sort | uniq -d | sed 's/^/  duplicate filename: /'
  done
  pause_prompt
}

show_storage_summary() {
  print_section_header "Maintenance: Storage Summary"
  local p
  for p in "$FINISHED_DIR" "$TEMP_DIR" "$WATCH_DIR" "$OUTPUT_BASE" "$MOVIES_DIR" "$SERIES_DIR"; do
    if [ -d "$p" ]; then
      du -sh "$p" 2>/dev/null | sed "s#^#$p -> #"
    else
      echo "$p -> missing"
    fi
  done

  local containers
  containers="$(find_qbittorrent_containers)"
  if [ -n "$containers" ]; then
    echo
    echo "Docker-exposed mounts:"
    local c
    while IFS= read -r c; do
      [ -z "$c" ] && continue
      echo "Container: $c"
      inspect_container_mounts "$c" | sed 's/^/  /'
    done <<< "$containers"
  fi

  pause_prompt
}

test_plex_connectivity() {
  print_section_header "Maintenance: Plex Connectivity Test"
  local url="$PLEX_URL"
  if [ -n "$PLEX_TOKEN" ]; then
    url="$url?X-Plex-Token=$PLEX_TOKEN"
  fi
  echo "Testing: $PLEX_URL"
  if curl -fsS --max-time 10 "$url" >/dev/null; then
    echo "Plex connectivity: OK"
  else
    echo "Plex connectivity: FAILED"
  fi
  pause_prompt
}

configure_qb_settings() {
  print_section_header "CONFIGURATION: qBittorrent Integration"
  QBITTORRENT_VARIANT="$(prompt_with_default "qBittorrent variant (qbittorrent/qbittorrent-nox)" "$QBITTORRENT_VARIANT")"
  QBITTORRENT_MODE="$(prompt_with_default "qBittorrent mode (native/docker)" "$QBITTORRENT_MODE")"
  QBITTORRENT_CONTAINER="$(prompt_with_default "qBittorrent container name" "$QBITTORRENT_CONTAINER")"
  QB_CONFIG_PATH="$(prompt_with_default "qBittorrent config path" "$QB_CONFIG_PATH")"
  DOCKER_COMPOSE_FILE="$(prompt_with_default "Docker compose file path" "$DOCKER_COMPOSE_FILE")"
  QBITTORRENT_COMPLETION_HOOK="$(build_qb_hook_command)"
  save_config
  show_integration_summary
  pause_prompt
}

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

  echo "SnorlaxBot auto mode: processing completed item only"
  echo "Resolved item path: $selected_path"
  run_filebot_on_path "$selected_path" "normal"
}

show_setup_menu() {
  while true; do
    print_section_header "SETUP"
    cat <<MENU
1) First-setup discovery + path mapping
2) Check dependencies/environment
3) Discover qBittorrent (native + Docker)
4) Install/update qBittorrent completion hook
5) Verify qBittorrent completion hook
6) qBittorrent optimization assistance
7) Back
MENU
    read -r -p "Choose an option: " choice
    case "$choice" in
      1) first_setup_flow ;;
      2) check_dependencies; pause_prompt ;;
      3) display_qb_discovery ;;
      4) install_hook_guidance ;;
      5) verify_hook_setup ;;
      6) show_qb_optimization_help ;;
      7) return ;;
      *) echo "Invalid option"; pause_prompt ;;
    esac
  done
}

show_configuration_menu() {
  while true; do
    print_section_header "CONFIGURATION"
    cat <<MENU
1) Configure API credentials
2) Configure directory paths
3) Configure qBittorrent integration
4) View current integration summary
5) Back
MENU
    read -r -p "Choose an option: " choice
    case "$choice" in
      1) configure_api_credentials ;;
      2) configure_directories ;;
      3) configure_qb_settings ;;
      4) show_integration_summary; pause_prompt ;;
      5) return ;;
      *) echo "Invalid option"; pause_prompt ;;
    esac
  done
}

show_processing_menu() {
  while true; do
    print_section_header "PROCESSING"
    cat <<MENU
1) Run FileBot (Finished)
2) Run FileBot (Temp)
3) Run FileBot (Custom Path)
4) Run FileBot (Forced)
5) Run FileBot (Dry Run)
6) Back
MENU
    read -r -p "Choose an option: " choice
    case "$choice" in
      1) run_filebot_finished ;;
      2) run_filebot_temp ;;
      3) run_filebot_custom ;;
      4) run_filebot_force ;;
      5) run_filebot_dry ;;
      6) return ;;
      *) echo "Invalid option"; pause_prompt ;;
    esac
  done
}

show_testing_menu() {
  while true; do
    print_section_header "INTEGRATION & TESTING"
    cat <<MENU
1) BBB Test via qBittorrent
2) BBB Test via transmission-cli
3) Verify qBittorrent hook command
4) Back
MENU
    read -r -p "Choose an option: " choice
    case "$choice" in
      1) bbb_test_qbittorrent ;;
      2) bbb_test_transmission_cli ;;
      3) verify_hook_setup ;;
      4) return ;;
      *) echo "Invalid option"; pause_prompt ;;
    esac
  done
}

show_maintenance_menu() {
  while true; do
    print_section_header "MAINTENANCE & DIAGNOSTICS"
    cat <<MENU
1) View logs
2) Filter/search logs
3) Recent import reports
4) Cleanup preview and optional delete
5) Junk scrubber
6) Mount/permission/disk checks
7) Duplicate detection
8) Storage summary (host + Docker mappings)
9) Plex connectivity test
10) Back
MENU
    read -r -p "Choose an option: " choice
    case "$choice" in
      1) show_logs ;;
      2) search_logs ;;
      3) show_recent_import_reports ;;
      4) cleanup_preview ;;
      5) scrub_junk_files ;;
      6) check_mount_permissions_disk ;;
      7) find_duplicates ;;
      8) show_storage_summary ;;
      9) test_plex_connectivity ;;
      10) return ;;
      *) echo "Invalid option"; pause_prompt ;;
    esac
  done
}

show_main_menu() {
  while true; do
    print_title_area
    cat <<MENU
1) SETUP
2) CONFIGURATION
3) PROCESSING
4) INTEGRATION & TESTING
5) MAINTENANCE & DIAGNOSTICS
6) View integration summary
7) Exit
MENU
    read -r -p "Choose an option: " choice
    case "$choice" in
      1) show_setup_menu ;;
      2) show_configuration_menu ;;
      3) show_processing_menu ;;
      4) show_testing_menu ;;
      5) show_maintenance_menu ;;
      6) show_integration_summary; pause_prompt ;;
      7) exit 0 ;;
      *) echo "Invalid option"; pause_prompt ;;
    esac
  done
}

main() {
  resolve_script_path
  load_config
  ensure_dirs

  if [ "${1:-}" = "--auto-filebot" ]; then
    shift
    run_auto_filebot "${1:-}" "${2:-}" "${3:-}"
    exit $?
  fi

  show_main_menu
}

main "$@"
