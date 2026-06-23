#!/bin/bash
# 20_cuda_toolkit.sh

set -euo pipefail

# : "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

if [[ "${SAFE_MODE:-0}" -eq 1 ]]; then
    log_info "CUDA skipped (SAFE MODE)"
    exit 0
fi

if ! lspci | grep -qi nvidia; then
    log_info "No NVIDIA GPU detected — skipping CUDA"
    exit 0
fi

PIPELINE_MODE="${PIPELINE_MODE:-default}"
ENABLE_CUDA="${ENABLE_CUDA:-y}"

if [[ "$PIPELINE_MODE" == "standard" && "$ENABLE_CUDA" != "y" ]]; then
    log_info "CUDA disabled in STANDARD mode"
    exit 0
fi

if ! sudo apt install -y nvidia-cuda-toolkit; then
    log_error "CUDA toolkit installation failed"
    exit 1
fi

log_info "=== Completed $MODULE_NAME ==="
