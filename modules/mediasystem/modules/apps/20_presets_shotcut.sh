#!/usr/bin/env bash
# 20_presets_shotcut.sh

set -euo pipefail

: "${SHARED_DIR:?}"

# init module name
export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

# logging
source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

source "${STATE_LIB:?}"
source "$SHARED_DIR/shotcut_env.sh"

state_init
IFS=',' read -r -a SELECTED_PRESETS <<< "$(state_get SELECTED_PRESETS)"

shotcut_write_presets "${SELECTED_PRESETS[@]}"
shotcut_sync_log "${SELECTED_PRESETS[@]}"

log_info "=== Completed $MODULE_NAME ==="
