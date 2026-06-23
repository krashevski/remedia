#!/bin/bash
# 40_gpu_ffmpeg_check.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

if ! command -v ffmpeg &>/dev/null; then
    log_warn "ffmpeg not found, skipping NVENC check"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

NVENC_LIST="$(ffmpeg -hide_banner -encoders 2>/dev/null | grep -i nvenc || true)"

if [[ -n "$NVENC_LIST" ]]; then
    log_info "NVENC encoders available:"
    echo "$NVENC_LIST" | while read -r line; do
        log_info "  $line"
    done
else
    log_warn "NVENC encoders not found"
fi

log_info "=== Completed $MODULE_NAME ==="
