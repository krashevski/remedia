#!/usr/bin/env bash
# 10_snap_packages.sh

set -euo pipefail

: "${SHARED_DIR:?}"
: "${PACK_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

log_info "=== Starting $MODULE_NAME ==="

# -------------------------
# SAFE CHECKS FIRST
# -------------------------
if [[ ! -d "$PACK_DIR" ]]; then
    log_error "Package directory not found: $PACK_DIR"
    exit 1
fi

FILE="$PACK_DIR/snap.txt"

if [[ ! -f "$FILE" ]]; then
    log_warn "Package list not found: $FILE — skipping"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

# -------------------------
# sudo check (after validation)
# -------------------------
if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

# -------------------------
# snap availability
# -------------------------
if ! command -v snap &>/dev/null; then
    log_info "snap not found, installing snapd..."
    sudo apt update && sudo apt install -y snapd
fi

# -------------------------
# INSTALL LOOP
# -------------------------
while read -r pkg; do
    [[ -z "$pkg" ]] && continue

    log_info "Installing $pkg"

    if sudo snap install "$pkg"; then
        log_info "Installed $pkg"
    else
        log_warn "Snap install failed for $pkg"
    fi

done < <(grep -v '^#' "$FILE" | grep -v '^$')

log_info "=== Completed $MODULE_NAME ==="
