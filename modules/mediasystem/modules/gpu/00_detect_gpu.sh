#!/usr/bin/env bash
# 00_detect_gpu.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

if command -v lspci >/dev/null 2>&1; then
    if lspci | grep -qi nvidia; then
        log_info "NVIDIA GPU detected"
    else
        log_warn "No NVIDIA GPU found"
    fi
else
    log_warn "lspci not found — skipping GPU detection"
fi

log_info "=== Completed $MODULE_NAME ==="
