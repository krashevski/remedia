#!/usr/bin/env bash
# core/system_bootstrap.sh

init_backupkit_system_fs() {
    groupadd -f backupkit
    local BACKUP_ROOT="${BACKUP_ROOT:-/mnt/backups/backupkit}"
    mkdir -p "$BACKUP_ROOT/user_data"

    chown root:backupkit "$BACKUP_ROOT/user_data"
    chmod 2775 "$BACKUP_ROOT/user_data"
}
