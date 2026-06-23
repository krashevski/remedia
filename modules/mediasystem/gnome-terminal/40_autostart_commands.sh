#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
if [[ -z "${SHARED_DIR:-}" ]]; then
    echo "ERROR: SHARED_DIR not set"
    exit 1
fi

for lib in log.sh ui.sh; do
    if [[ ! -f "$SHARED_DIR/$lib" ]]; then
        echo "ERROR: Missing $lib in $SHARED_DIR"
        exit 1
    fi
    source "$SHARED_DIR/$lib"
done

# --- safe default ---
SSH_KEY_ADDED=${SSH_KEY_ADDED:-0}

log_info "=== Starting 40_autostart_commands.sh ==="

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

log_info "=== Completed 40_autostart_commands.sh ==="
