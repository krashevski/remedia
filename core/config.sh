#!/usr/bin/env bash
# core/config.sh

load_config() {
    local CONFIG="/etc/remedia/remedia.env"

    if [[ -f "$CONFIG" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG"
        log_info "config loaded: $CONFIG"
    else
        log_warn "config not found, using defaults"
    fi

    : "${FAST_STORAGE:=/mnt/shotcut}"
    : "${SLOW_STORAGE:=/mnt/storage}"
    : "${BACKUP_STORAGE:=/mnt/backups}"

    log_debug "[CONFIG] FAST_STORAGE=$FAST_STORAGE"
    log_debug "[CONFIG] SLOW_STORAGE=$SLOW_STORAGE"
    log_debug "[CONFIG] BACKUP_STORAGE=$BACKUP_STORAGE"
}
