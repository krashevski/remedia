#!/bin/bash
# 70_obs_install.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

# -------------------------
# SAFE MODE FIRST
# -------------------------
if [ "${SAFE_MODE:-0}" -eq 1 ]; then
    log_info "[SAFE MODE] Skipping OBS"
    log_info "=== Completed $MODULE_NAME ==="
    exit 100
fi

# -------------------------
# sudo check AFTER safe mode
# -------------------------
if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

ENABLE_OBS=y

if [ "${PIPELINE_MODE:-}" = "full" ] && [ "$ENABLE_OBS" != "y" ]; then
    log_info "[CUSTOM MODE] OBS disabled"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

# -------------------------
# CHECK EXISTENCE
# -------------------------
if command -v obs &>/dev/null || command -v obs-studio &>/dev/null; then
    log_info "OBS Studio already installed"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

log_info "Installing OBS Studio via APT..."

if sudo apt update && sudo apt install -y obs-studio; then
    log_info "OBS Studio installed successfully"
else
    log_error "Failed to install OBS Studio via APT"
fi

log_info "=== Completed $MODULE_NAME ==="
