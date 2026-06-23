#!/bin/bash
# 70_gpu_info.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

if ! command -v lspci &>/dev/null; then
    log_warn "lspci not available"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

if lspci | grep -qi nvidia; then
    log_info "NVIDIA GPU detected"
else
    log_warn "No NVIDIA GPU found"
fi

log_info "=== Completed $MODULE_NAME ==="
