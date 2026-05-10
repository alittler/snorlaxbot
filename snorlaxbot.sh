#!/bin/bash
# ============================================================
#  filebot-manager.sh
#  FileBot AMC — Terminal Management Interface
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# ── Colors ───────────────────────────────────────────────────
CY='\033[0;36m'   # cyan       — labels, brackets
GR='\033[0;32m'   # green      — menu items
YE='\033[1;33m'   # yellow     — warnings / highlights
RE='\033[0;31m'   # red        — errors
BL='\033[0;34m'   # blue       — ascii art / dividers
WH='\033[1;37m'   # white bold — section headers
DI='\033[2m'      # dim
N='\033[0m'       # reset

# ── Defaults ─────────────────────────────────────────────────
DEFAULT_FINISHED_DIR="/mnt/Media/Torrents/finished"
DEFAULT_TEMP_DIR="/mnt/Media/Torrents/temp"
DEFAULT_OUTPUT_BASE="/mnt/Media"
DEFAULT_MOVIES_DIR="/mnt/Media/Movies"
DEFAULT_SERIES_DIR="/mnt/TV_Shows/TV Shows"
DEFAULT_PLEX_HOST="localhost"

# ── Load / Save .env ─────────────────────────────────────────
load_config() {
  [[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
  FINISHED_DIR="${FINISHED_DIR:-$DEFAULT_FINISHED_DIR}"
  TEMP_DIR="${TEMP_DIR:-$DEFAULT_TEMP_DIR}"
  OUTPUT_BASE="${OUTPUT_BASE:-$DEFAULT_OUTPUT_BASE}"
  MOVIES_DIR="${MOVIES_DIR:-$DEFAULT_MOVIES_DIR}"
  SERIES_DIR="${SERIES_DIR:-$DEFAULT_SERIES_DIR}"
  PLEX_HOST="${PLEX_HOST:-$DEFAULT_PLEX_HOST}"
  PLEX_TOKEN="${PLEX_TOKEN:-}"
  GMAIL_USER="${GMAIL_USER:-}"
  GMAIL_PASS="${GMAIL_PASS:-}"
  PUSHOVER_USER="${PUSHOVER_USER:-}"
  PUSHOVER_TOKEN="${PUSHOVER_TOKEN:-}"
}

save_config() {
  cat > "$ENV_FILE" <<EOF
# FileBot Manager .env — $(date)
FINISHED_DIR="$FINISHED_DIR"
TEMP_DIR="$TEMP_DIR"
OUTPUT_BASE="$OUTPUT_BASE"
MOVIES_DIR="$MOVIES_DIR"
SERIES_DIR="$SERIES_DIR"
PLEX_HOST="$PLEX_HOST"
PLEX_TOKEN="$PLEX_TOKEN"
GMAIL_USER="$GMAIL_USER"
GMAIL_PASS="$GMAIL_PASS"
PUSHOVER_USER="$PUSHOVER_USER"
PUSHOVER_TOKEN="$PUSHOVER_TOKEN"
EOF
  chmod 600 "$ENV_FILE"
}

# ── UI Primitives ─────────────────────────────────────────────
divider() { echo -e "${BL}$(printf '═%.0s' {1..70})${N}"; }
thin()    { echo -e "${DI}$(printf '─%.0s' {1..70})${N}"; }
blank()   { echo ""; }

ok()   { echo -e "  ${GR}[  OK  ]${N}  $1"; }
fail() { echo -e "  ${RE}[ FAIL ]${N}  $1"; }
info() { echo -e "  ${CY}[ INFO ]${N}  $1"; }
warn() { echo -e "  ${YE}[ WARN ]${N}  $1"; }

confirm() {
  printf "  ${CY}$1 [y/N]:${N} "
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

prompt_input() {
  local label="$1" current="$2"
  printf "  ${CY}%-24s${N} ${DI}[%s]${N}\n  ${GR}>${N} " "$label" "$current"
  read -r REPLY
  [[ -z "$REPLY" ]] && REPLY="$current"
}

prompt_secret() {
  local label="$1"
  printf "  ${CY}%-24s${N} ${DI}[hidden]${N}\n  ${GR}>${N} " "$label"
  read -rs REPLY
  echo ""
}

pause() {
  blank
  printf "  ${DI}Press Enter to continue...${N}"
  read -r
}

# ── ASCII Header ──────────────────────────────────────────────
print_header() {
  clear
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
  echo -e "  ${DI}ENV: $ENV_FILE${N}"
  divider
  blank
}

# ── Section header (inside submenus) ─────────────────────────
section_header() {
  clear
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
  info "Packages: filebot  openjdk-17-jre  curl"
  blank
  confirm "Run apt update + install?" || return
  blank
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y filebot openjdk-17-jre curl
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
  prompt_input "Output base"       "$OUTPUT_BASE";   OUTPUT_BASE="$REPLY"
  prompt_input "Movies dir"        "$MOVIES_DIR";    MOVIES_DIR="$REPLY"
  prompt_input "TV Shows dir"      "$SERIES_DIR";    SERIES_DIR="$REPLY"
  mkdir -p "$MOVIES_DIR" "$SERIES_DIR" 2>/dev/null
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
  prompt_input  "Host" "$PLEX_HOST";  PLEX_HOST="$REPLY"
  prompt_secret "Token";              [[ -n "$REPLY" ]] && PLEX_TOKEN="$REPLY"
  blank

  echo -e "  ${WH}GMAIL${N}"
  prompt_input  "Address"      "$GMAIL_USER"; GMAIL_USER="$REPLY"
  prompt_secret "App password";               [[ -n "$REPLY" ]] && GMAIL_PASS="$REPLY"
  blank

  echo -e "  ${WH}PUSHOVER${N}"
  prompt_secret "User key";   [[ -n "$REPLY" ]] && PUSHOVER_USER="$REPLY"
  prompt_secret "API token";  [[ -n "$REPLY" ]] && PUSHOVER_TOKEN="$REPLY"

  save_config
  blank
  ok "Credentials saved → $ENV_FILE (chmod 600)"
  pause
}

setup_show_command() {
  local mfmt="$MOVIES_DIR/{n} ({y})"
  local sfmt="$SERIES_DIR/{n}/{'Season '+s}/{n} - {s00e00}"
  section_header "SETUP & CONFIGURATION  //  CURRENT AMC COMMAND"
  echo -e "  ${GR}filebot${N} ${CY}-script${N} fn:amc \\\n    ${CY}--output${N}    \"$OUTPUT_BASE\" \\\n    ${CY}--action${N}    copy \\\n    ${CY}-non-strict${N} \\\n    ${CY}--def${N} \"ut_kind=multi\" \\\n    ${CY}--def${N} \"ut_dir=$FINISHED_DIR\" \\\n    ${CY}--def${N} \"movieFormat=$mfmt\" \\\n    ${CY}--def${N} \"seriesFormat=$sfmt\" \\\n    ${CY}--def${N} plex=\"$PLEX_HOST:${PLEX_TOKEN:0:6}***\" \\\n    ${CY}--def${N} pushover=\"${PUSHOVER_USER:0:6}***:${PUSHOVER_TOKEN:0:6}***\" \\\n    ${CY}--def${N} gmail=\"$GMAIL_USER:***\""
  blank
  echo -e "  ${DI}Secrets truncated — full values used at runtime${N}"
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
    for e in "${errors[@]}"; do fail "$e"; done
    pause
    return 1
  fi
  return 0
}

_run_filebot() {
  local extra_flags="$1"
  local source_dir="$2"
  local mfmt="$MOVIES_DIR/{n} ({y})"
  local sfmt="$SERIES_DIR/{n}/{'Season '+s}/{n} - {s00e00}"

  [[ -z "$source_dir" ]] && source_dir="$FINISHED_DIR"

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
  pause
}

# ════════════════════════════════════════════════════════════
#  SYSTEM & MAINTENANCE
# ════════════════════════════════════════════════════════════

maint_view_logs() {
  section_header "SYSTEM & MAINTENANCE  //  VIEW LOGS"
  local log_dir="/var/log/filebot"
  if [[ ! -d "$log_dir" ]]; then
    warn "Log directory not found: $log_dir"
    pause
    return
  fi
  info "Recent log files:"
  blank
  ls -lt "$log_dir"/*.log 2>/dev/null | head -10
  blank
  local latest
  latest=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
  if [[ -n "$latest" ]]; then
    confirm "Tail latest log ($latest)?" && tail -40 "$latest"
  fi
  pause
}

maint_scrub_junk() {
  section_header "SYSTEM & MAINTENANCE  //  SCRUB JUNK FILES"
  info "Removes .nfo  .txt  .jpg  .jpeg  .png  .sfv  .nzb  sample files from output"
  blank
  confirm "Continue?" || return
  blank
  find "$OUTPUT_BASE" \( \
    -iname "*.nfo" -o \
    -iname "*.txt" -o \
    -iname "*.jpg" -o \
    -iname "*.jpeg" -o \
    -iname "*.png" -o \
    -iname "*.sfv" -o \
    -iname "*.nzb" -o \
    -iname "*sample*" \
  \) -delete \
    && ok "Junk files removed from $OUTPUT_BASE" \
    || fail "Scrub encountered errors"
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
    rm -rf "${FINISHED_DIR:?}"/* || failed=1
  else
    warn "Finished dir not found: $FINISHED_DIR"
  fi

  if [[ -d "$TEMP_DIR" ]]; then
    rm -rf "${TEMP_DIR:?}"/* || failed=1
  else
    warn "Temp dir not found: $TEMP_DIR"
  fi

  [[ $failed -eq 0 ]] && ok "Finished/temp dirs emptied" || fail "Delete failed"
  pause
}

maint_upgrade() {
  section_header "SYSTEM & MAINTENANCE  //  SYSTEM UPGRADE & RE-VERIFY DEPS"
  info "apt update / upgrade / autoremove + verify filebot + java"
  blank
  confirm "Continue?" || return
  blank
  sudo apt update && sudo apt upgrade -y
  sudo apt autoremove -y && sudo apt autoclean
  blank
  command -v filebot &>/dev/null \
    && ok "filebot:  $(filebot --version 2>/dev/null | head -1)" \
    || fail "filebot not found"
  command -v java &>/dev/null \
    && ok "java:     $(java -version 2>&1 | head -1)" \
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
    && { warn "Pushover credentials not set — skipping"; } \
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

# ════════════════════════════════════════════════════════════
#  MAIN MENU
# ════════════════════════════════════════════════════════════

main_menu() {
  while true; do
    print_header

    echo -e "  ${WH}SETUP & CONFIGURATION${N}"
    echo -e "  ${CY}[01]${N} ${GR}Update Environment & Credentials${N}"
    echo -e "  ${CY}[02]${N} ${GR}Configure Directories${N}"
    echo -e "  ${CY}[03]${N} ${GR}Show Dynamic AMC FileBot Command${N}"
    echo -e "  ${CY}[04]${N} ${GR}Install / Re-verify Dependencies${N}"
    blank

    echo -e "  ${WH}CORE PROCESSING${N}"
    echo -e "  ${CY}[05]${N} ${GR}Run Move (Finished)${N}"
    echo -e "  ${CY}[06]${N} ${GR}Run Move (Temp)${N}"
    echo -e "  ${CY}[07]${N} ${GR}Forced Run (Ignore History)${N}"
    echo -e "  ${CY}[08]${N} ${GR}Simulation Mode (Dry Run)${N}"
    blank

    echo -e "  ${WH}SYSTEM & MAINTENANCE${N}"
    echo -e "  ${CY}[09]${N} ${GR}View Logs${N}"
    echo -e "  ${CY}[10]${N} ${GR}Scrub Junk Files${N}"
    echo -e "  ${CY}[11]${N} ${GR}Wipe AMC History${N}"
    echo -e "  ${CY}[12]${N} ${GR}Empty Finished/TEMP${N}"
    echo -e "  ${CY}[13]${N} ${YE}SYSTEM UPGRADE & RE-VERIFY DEPS${N}"
    blank

    echo -e "  ${WH}ALERTS & TESTING${N}"
    echo -e "  ${CY}[14]${N} ${GR}Test Notifications${N}"
    echo -e "  ${CY}[15]${N} ${GR}Run Test Cycle${N}"
    echo -e "  ${CY}[16]${N} ${GR}Trigger Configuration Backup${N}"
    blank

    echo -e "  ${WH}SYSTEM${N}"
    echo -e "  ${CY}[00]${N} ${RE}TERMINATE SESSION${N}"
    blank
    divider
    printf "  ${WH}SELECT OPTION:${N} "
    read -r choice

    case "$choice" in
      01|1) setup_configure_creds ;;
      02|2) setup_configure_dirs ;;
      03|3) setup_show_command ;;
      04|4) setup_install_deps ;;
      05|5) core_run_finished ;;
      06|6) core_run_temp ;;
      07|7) core_run_force ;;
      08|8) core_run_dry ;;
      09|9) maint_view_logs ;;
      10)   maint_scrub_junk ;;
      11)   maint_wipe_history ;;
      12)   maint_empty_finished ;;
      13)   maint_upgrade ;;
      14)   alerts_test_notifications ;;
      15)   alerts_test_cycle ;;
      16)   alerts_backup ;;
      00|0) break ;;
      *)    warn "Invalid selection"; pause ;;
    esac
  done

  clear
  echo -e "${BL}$(printf '═%.0s' {1..70})${N}"
  echo -e "  ${DI}SESSION TERMINATED${N}"
  echo -e "${BL}$(printf '═%.0s' {1..70})${N}"
  echo ""
}

# ════════════════════════════════════════════════════════════
load_config
main_menu
