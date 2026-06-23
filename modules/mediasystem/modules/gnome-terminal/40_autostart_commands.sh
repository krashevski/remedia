#!/bin/bash
# 40_autostart_commands.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"
: "${MODULE_ROOT:?}"
source "$SHARED_DIR/log.sh"
log_init

# --- safe default ---
SSH_KEY_ADDED=${SSH_KEY_ADDED:-0}

log_info "=== Starting ${MODULE_NAME:-unknown} ==="

# --- SSH agent autostart ---
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    log_info "Starting ssh-agent..."
    eval "$(ssh-agent -s)"
else
    log_info "ssh-agent already running"
fi

# --- Добавляем ключ, если не добавлен и не добавлялся в этой сессии ---
if [ "$SSH_KEY_ADDED" -eq 0 ]; then
    if ssh-add -l >/dev/null 2>&1; then
        log_info "SSH key already added"
    elif [ -f "$HOME/.ssh/id_ed25519" ]; then
        log_info "Adding SSH key ~/.ssh/id_ed25519 (non-blocking)"
        # Попытка добавить ключ, если требует пароль — просто логируем предупреждение
        ssh-add ~/.ssh/id_ed25519 </dev/null >/dev/null 2>&1 || log_warn "SSH key requires passphrase or failed to add"
    else
        log_warn "SSH key ~/.ssh/id_ed25519 not found"
    fi
    export SSH_KEY_ADDED=1
fi

log_info "=== Completed $MODULE_NAME ==="
