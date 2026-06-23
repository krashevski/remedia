#!/bin/bash
# 50_opengl_check.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

log_info "=== Starting $MODULE_NAME ==="

# check dependency
if ! command -v glxinfo &>/dev/null; then
    log_warn "glxinfo not found, installing mesa-utils..."
    if ! sudo apt install -y mesa-utils; then
        log_error "Failed to install mesa-utils"
        log_info "=== Completed $MODULE_NAME ==="
        exit 1
    fi
fi

# check runtime environment
if ! glxinfo &>/dev/null; then
    log_warn "glxinfo cannot run (no X server / DISPLAY)"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

OPENGL_RENDERER=$(glxinfo 2>/dev/null \
    | grep "OpenGL renderer" \
    | cut -d: -f2- \
    | xargs || true)

if [[ -n "$OPENGL_RENDERER" ]]; then
    log_info "OpenGL renderer: $OPENGL_RENDERER"
else
    log_warn "OpenGL renderer not detected"
fi

log_info "=== Completed $MODULE_NAME ==="
