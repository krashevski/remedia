#!/usr/bin/env bash
# 00_detect_gpu.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

command -v lspci >/dev/null 2>&1 || {
    log_warn "lspci not found — skipping GPU detection"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
}

if lspci | grep -qi nvidia; then
    log_info "NVIDIA GPU detected"
else
    log_warn "No NVIDIA GPU found"
fi

log_info "=== Completed $MODULE_NAME ==="
