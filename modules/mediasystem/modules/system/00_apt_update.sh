#!/usr/bin/env bash
# 00_apt_update.sh

set -euo pipefail

# : "${MODULE_ROOT:?}"
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

log_info "=== Starting $MODULE_NAME ==="

# run command with logging
if sudo apt update >> "${LOG_FILE:-/dev/null}" 2>&1; then
  log_info "apt update completed"
else
  log_error "apt update failed"
  exit 1
fi

log_info "=== Completed $MODULE_NAME ==="
