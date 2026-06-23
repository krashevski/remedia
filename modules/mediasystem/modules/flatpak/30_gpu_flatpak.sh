#!/usr/bin/env bash
# modules/mediasystem/modules/flatpak/30_gpu_flatpak.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

if ! command -v flatpak &>/dev/null; then
    log_warn "Flatpak not found. Skipping GPU Flatpak setup."
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

log_info "Enabling NVIDIA GPU for Shotcut in Flatpak..."

if ! flatpak override --user \
    --device=dri \
    --env=LIBVA_DRIVER_NAME=nvidia \
    org.shotcut.Shotcut; then
    log_error "Failed to apply Flatpak GPU override"
    log_info "=== Completed $MODULE_NAME ==="
    exit 1
fi

# --- NVENC check ---
if command -v ffmpeg &>/dev/null; then
    if ffmpeg -encoders 2>/dev/null | grep -qi nvenc; then
        log_info "[GPU] NVENC available (system ffmpeg)"
    else
        log_warn "[GPU] NVENC not detected (system ffmpeg)"
    fi
else
    log_warn "ffmpeg not available for NVENC check"
fi

log_info "=== Completed $MODULE_NAME ==="
