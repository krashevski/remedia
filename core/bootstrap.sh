#!/usr/bin/env bash
# core/bootstrap.sh - environment bootstrap

set -euo pipefail

CONFIG="/etc/remedia/remedia.env"

if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
else
    echo "[WARN] config not found, using defaults"
fi

# -------------------------
# BASE PATHS
# -------------------------
: "${PREFIX:=/usr}"
: "${REMEDIA_LIB:=$PREFIX/lib/remedia}"
[[ -n "${REMEDIA_LIB:-}" ]] || {
    echo "[FATAL] REMEDIA_LIB not set"
    exit 1
}

export ORIGINAL_ARGS_STR="$*"

export REMEDIA_BIN="$REMEDIA_ROOT/bin"
export REMEDIA_CORE="$REMEDIA_ROOT/core"

# LOGGING
if [[ "$EUID" -eq 0 ]]; then
    export LOG_DIR="${LOG_DIR:-$REMEDIA_VAR/logs}"
else
    export LOG_DIR="${LOG_DIR:-/var/log/remedia}"
fi

# STORAGE
export FAST_STORAGE="${FAST_STORAGE:-/mnt/shotcut}"
export SLOW_STORAGE="${SLOW_STORAGE:-/mnt/storage}"
export BACKUP_STORAGE="${BACKUP_STORAGE:-/mnt/backups}"

export PROJECT_DIR="${PROJECT_DIR:-$SLOW_STORAGE/Videos/projects}"

# MODULES
export REMEDIA_MODULES="${REMEDIA_MODULES:-$REMEDIA_LIB/modules}"

# DEBUG
# export REMEDIA_LOG_LEVEL=DEBUG   # включает всё
export REMEDIA_LOG_LEVEL=INFO    # убирает DEBUG
# export REMEDIA_LOG_LEVEL=ERROR   # почти тишина

# SHOTCUT_DIR
export SHOTCUT_DIR="${SHOTCUT_DIR:-$HOME/.config/Shotcut}"

# LOG SETTINGS
export LOG_FILE="${LOG_FILE:-$LOG_DIR/remedia.log}"
export LOG_MAX_SIZE="${LOG_MAX_SIZE:-$((5 * 1024 * 1024))}"
export LOG_MAX_FILES="${LOG_MAX_FILES:-3}"

# INIT DIRECTORIES
ensure_dir "$LOG_DIR"
ensure_dir "$BACKUP_STORAGE"
ensure_dir "$SHOTCUT_DIR"
ensure_dir "$STATE_DIR"

if [[ "${REMEDIA_QUIET:-0}" -eq 0 ]]; then
    echo "[Runtime] ready"
fi
log_debug "REMEDIA_LIB=$REMEDIA_LIB"
log_debug "BACKUP_STORAGE=$BACKUP_STORAGE"
