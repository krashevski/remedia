#!/bin/bash
# 60_apt_packages.sh

set -euo pipefail

: "${SHARED_DIR:?}"

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

if [[ ! -d "$PACK_DIR" ]]; then
    echo "ERROR: Package directory not found: $PACK_DIR"
    exit 1
fi

FILE="$PACK_DIR/apt_media.txt"

if [[ ! -f "$FILE" ]]; then
    log_warn "Package list not found: $FILE — skipping"
    exit 0
fi

log_info "=== Starting $MODULE_NAME ==="

if [[ ! -f "$FILE" ]]; then
    log_error "APT package list not found: $APT_FILE"
    exit 1
fi

grep -v '^#' "$FILE" | grep -v '^$' | xargs -r sudo apt install -y

log_info "=== Completed $MODULE_NAME ==="
