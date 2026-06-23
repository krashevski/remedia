#!/usr/bin/env bash
# modules/mediasystem/shared-lib/log.sh — production-grade logging

# -------------------------
# CONFIG (lazy defaults)
# -------------------------
get_log_level_num() {
    case "${LOG_LEVEL:-INFO}" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        *)     echo 1 ;;
    esac
}

should_log() {
    local level="$1"

    local current=$(get_log_level_num)
    local target

    case "$level" in
        DEBUG) target=0 ;;
        INFO)  target=1 ;;
        WARN)  target=2 ;;
        ERROR) target=3 ;;
        *)     target=1 ;;
    esac

    [[ "$target" -ge "$current" ]]
}

# -------------------------
# ROTATION
# -------------------------
rotate_logs() {
    local logfile="$1"
    local max_size="${LOG_MAX_SIZE:-5242880}"   # 5MB
    local max_files="${LOG_MAX_FILES:-3}"

    [[ -f "$logfile" ]] || return 0

    local size
    size=$(stat -c%s "$logfile" 2>/dev/null || echo 0)

    if (( size < max_size )); then
        return 0
    fi

    # rotate: file.log -> file.log.1 -> file.log.2 ...
    for ((i=max_files; i>=1; i--)); do
        if [[ -f "${logfile}.${i}" ]]; then
            if (( i == max_files )); then
                rm -f "${logfile}.${i}"
            else
                mv "${logfile}.${i}" "${logfile}.$((i+1))"
            fi
        fi
    done

    mv "$logfile" "${logfile}.1"
}

# -------------------------
# CORE LOG
# -------------------------
log() {
    local level="$1"; shift

    should_log "$level" || return 0


    local logfile="${LOG_FILE:-$LOG_DIR/mediapanel.log}"

    rotate_logs "$logfile"

    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    local msg="$ts [$level] [$module] $*"

    mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
    echo "$msg" >> "$logfile"

    # colors
    local GREEN="\033[0;32m"
    local RED="\033[0;31m"
    local YELLOW="\033[0;33m"
    local BLUE="\033[0;34m"
    local GRAY="\033[0;90m"
    local NC="\033[0m"

    case "$level" in
        DEBUG) echo -e "$ts [${GRAY}DEBUG${NC}] [$module] $*" ;;
        INFO)  echo -e "$ts [${BLUE}INFO${NC}] [$module] $*" ;;
        WARN)  echo -e "$ts [${YELLOW}WARN${NC}] [$module] $*" ;;
        ERROR) echo -e "$ts [${RED}ERROR${NC}] [$module] $*" ;;
    esac
}

# -------------------------
# SHORTCUTS
# -------------------------
log_debug() { log "DEBUG" "$*"; }
log_info()  { log "INFO"  "$*"; }
log_warn()  { log "WARN"  "$*"; }
log_error() { log "ERROR" "$*"; }

# -------------------------
# DEBUG MODE
# -------------------------
enable_debug() {
    export LOG_LEVEL="DEBUG"
    log_debug "Debug mode enabled"
}

# -------------------------
# INIT (optional)
# -------------------------
log_init() {
    [[ "${LOG_INIT_DONE:-0}" == 1 ]] && return 0
    export LOG_INIT_DONE=1
    
    local module="${MODULE_NAME:-unknown_module}"
    local logfile="${LOG_FILE:-$LOG_DIR/${module}.log}"

    mkdir -p "$(dirname "$logfile")"

    if [[ "${REMEDIA_DEBUG:-0}" == 1 ]]; then
        echo "DEBUG LOGFILE=$logfile"
    fi

    {
        echo "==============================="
        echo "=== START: $module === $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==============================="
    } >> "$logfile"
}

log_init_once() {
    if [[ "${LOG_INIT_DONE:-0}" -eq 1 ]]; then
        return 0
    fi
    log_init
    export LOG_INIT_DONE=1
}
