#!/usr/bin/env bash
# 10_nvidia_driver.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

command -v ubuntu-drivers >/dev/null 2>&1 || {
    log_info "ubuntu-drivers not found, skipping GPU driver install"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
}

if ! lspci | grep -qi nvidia; then
    log_info "No NVIDIA GPU detected — skipping driver install"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

if ! sudo ubuntu-drivers install; then
    log_error "NVIDIA driver installation failed"
    exit 1
fi

log_info "=== Completed $MODULE_NAME ==="
