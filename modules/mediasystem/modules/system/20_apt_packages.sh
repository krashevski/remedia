#!/usr/bin/env bash
# 20_apt_packages.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once

if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACK_DIR="${PACK_DIR:-$MODULE_DIR/packages}"

FILE="$PACK_DIR/apt_utils.txt"

if [[ ! -d "$PACK_DIR" ]]; then
    log_error "Package directory not found: $PACK_DIR"
    exit 1
fi

if [[ ! -f "$FILE" ]]; then
    log_warn "Package list not found: $FILE — skipping"
    exit 0
fi

log_info "=== Starting $MODULE_NAME ==="

grep -v '^#' "$FILE" | grep -v '^$' | xargs -r sudo apt install -y

log_info "=== Completed $MODULE_NAME ==="
