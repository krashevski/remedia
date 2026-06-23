#!/bin/bash
# 10_auto_gpu_presets.sh

set -euo pipefail 

: "${SHARED_DIR:?}"

# init module name
export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

# logging
source "$SHARED_DIR/log.sh"
log_init_once

source "${STATE_LIB:?}"

log_info "=== Starting $MODULE_NAME ==="

SELECTED_PRESETS=("nvenc_h264" "nvenc_hevc")
state_save SELECTED_PRESETS "nvenc_h264,nvenc_hevc"

log_info "=== Completed $MODULE_NAME ==="
