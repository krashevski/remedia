set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init

log_info "=== Starting ${MODULE_NAME:-unknown} ==="

if ! command -v flatpak &>/dev/null; then
    log_warn "Flatpak not found. Skipping GPU check."
    exit 0
fi

if ! flatpak list 2>/dev/null | grep -q org.shotcut.Shotcut; then
    log_warn "Shotcut not installed via Flatpak. Skipping."
    exit 0
fi

OPENGL_RENDERER="$(timeout 3s flatpak run --command=glxinfo org.shotcut.Shotcut 2>/dev/null \
    | grep "OpenGL renderer" || true)"

if [[ -z "$OPENGL_RENDERER" ]]; then
    log_warn "OpenGL not available (UI may fallback to software rendering)"
else
    log_info "OpenGL: $OPENGL_RENDERER"
fi

NVENC_LIST="$(timeout 3s flatpak run --command=ffmpeg org.shotcut.Shotcut -hide_banner -encoders 2>/dev/null \
    | grep nvenc || true)"

[[ -n "$NVENC_LIST" ]] && \
    log_info "NVENC available" || \
    log_warn "NVENC not available"

log_info "=== Completed $MODULE_NAME ==="
