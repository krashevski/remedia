#!/usr/bin/env bash
# 40_apt_cleanup_optional.sh

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

shopt -s nullglob

files=(/etc/apt/sources.list.d/*)

if [[ ${#files[@]} -eq 0 ]]; then
    log_info "No extra apt sources found"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

for file in "${files[@]}"; do
    if [[ -f "$file" && "$(basename "$file")" != "ubuntu.sources" ]]; then
        log_info "Removing: $file"
        if ! sudo rm -f "$file"; then
            log_warn "Failed to remove $file"
        fi
    fi
done

log_info "=== Completed $MODULE_NAME ==="
