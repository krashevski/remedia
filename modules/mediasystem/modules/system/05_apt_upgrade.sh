#!/usr/bin/env bash
# 05_apt_upgrade.sh

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

log_info "=== Starting $MODULE_NAME ==="

# sudo check
if ! sudo -n true 2>/dev/null; then
  log_error "sudo required (non-interactive mode)"
  exit 1
fi

# upgrade
if sudo apt upgrade -y -o Dpkg::Options::="--force-confnew" >> "${LOG_FILE:-/dev/null}" 2>&1; then
  log_info "apt upgrade completed"
else
  log_error "apt upgrade failed"
  exit 1
fi

log_info "=== Completed $MODULE_NAME ==="
