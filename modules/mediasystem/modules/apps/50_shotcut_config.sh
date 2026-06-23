#!/bin/bash
# 50_shotcut_config.sh

set -euo pipefail 

: "${SHARED_DIR:?}"
: "${MEDIASYSTEM_VAR:?MEDIASYSTEM_VAR not set}"
: "${SHOTCUT_DIR:?SHOTCUT_DIR not set}"

MODULE_NAME="50_shotcut_config.sh"

source "$SHARED_DIR/log.sh"
log_init

log_info "=== Starting $MODULE_NAME ==="

ENV_FILE="$MEDIASYSTEM_VAR/best_gpu_preset.env"

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    log_warn "No GPU preset file found"
fi

if [[ -z "${BEST_GPU_PRESET:-}" ]]; then
    log_error "BEST_GPU_PRESET is empty"
    exit 1
fi
echo "Shotcut config applied: $BEST_GPU_PRESET"

log_info "=== Completed $MODULE_NAME ==="
