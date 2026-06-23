#!/bin/bash
# 30_video_packages.sh

set -euo pipefail

: "${SHARED_DIR:?}"
: "${PACK_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

FILE="$PACK_DIR/video.txt"

if [[ ! -d "$PACK_DIR" ]]; then
    log_error "Package directory not found: $PACK_DIR"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    log_warn "Package list not found: $FILE — skipping"
    exit 0
fi

log_info "=== Starting $MODULE_NAME ==="

grep -v '^#' "$FILE" | grep -v '^$' | grep -v '^$' \
  | xargs -r sudo apt install -y >> "${LOG_FILE:-/dev/null}" 2>&1

log_info "=== Completed $MODULE_NAME ==="
