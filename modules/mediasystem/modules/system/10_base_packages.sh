#!/usr/bin/env bash
# 10_base_packages.sh

set -euo pipefail 

: "${SHARED_DIR:?}"
: "${PACK_DIR:?}"

# init module name
export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

# logging
source "$SHARED_DIR/log.sh"
log_init_once

# sudo check
if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

FILE="$PACK_DIR/base.txt"

# checks
if [[ ! -d "$PACK_DIR" ]]; then
    log_error "Package directory not found: $PACK_DIR"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    log_warn "Package list not found: $FILE — skipping"
    exit 0
fi

# sudo check
if ! sudo -n true 2>/dev/null; then
    log_error "sudo required (non-interactive mode)"
    exit 1
fi

log_info "=== Starting $MODULE_NAME ==="

# install packages safely (по одному)
while read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

    log_info "Installing: $pkg"

    if sudo apt install -y "$pkg" >> "${LOG_FILE:-/dev/null}" 2>&1; then
        log_debug "OK: $pkg"
    else
        log_error "FAIL: $pkg"
        exit 1
    fi

done < "$FILE"

log_info "=== Completed $MODULE_NAME ==="
