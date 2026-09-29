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

# --- NVIDIA driver extension for Flatpak + real NVENC check ---
if ! command -v nvidia-smi >/dev/null 2>&1; then
    log_info "[GPU] NVIDIA driver not detected; Shotcut can use CPU export"
else
    driver_version="$(nvidia-smi --query-gpu=driver_version \
        --format=csv,noheader 2>/dev/null | sed -n '1p')"

    if [[ ! "$driver_version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        log_warn "[GPU] Cannot determine NVIDIA driver version"
    else
        driver_ref="org.freedesktop.Platform.GL.nvidia-${driver_version//./-}//1.4"
        log_info "[GPU] NVIDIA driver: $driver_version"
        log_info "[GPU] Required Flatpak extension: $driver_ref"

        if ! flatpak info "$driver_ref" >/dev/null 2>&1; then
            if flatpak remote-info flathub "$driver_ref" \
                >/dev/null 2>&1; then
                log_info "[GPU] Installing matching Flatpak NVIDIA extension"

                if flatpak install -y flathub "$driver_ref" \
                    >> "${LOG_FILE:-/dev/null}" 2>&1; then
                    log_info "[GPU] NVIDIA extension installed"
                else
                    log_warn "[GPU] Failed to install $driver_ref"
                fi
            else
                log_warn "[GPU] $driver_ref is not available in Flathub"
            fi
        else
            log_info "[GPU] Matching NVIDIA extension is installed"
        fi
    fi

    if flatpak run --command=ffmpeg org.shotcut.Shotcut \
        -hide_banner -loglevel error \
        -f lavfi -i testsrc2=size=640x360:rate=30 \
        -t 1 -c:v h264_nvenc -f null - \
        >> "${LOG_FILE:-/dev/null}" 2>&1; then
        log_info "[GPU] Shotcut Flatpak NVENC OK"
    else
        log_warn "[GPU] Shotcut Flatpak NVENC failed; use CPU export"
    fi
fi

log_info "=== Completed $MODULE_NAME ==="
