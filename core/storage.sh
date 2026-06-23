#!/usr/bin/env bash
# core/storage.sh - только дефолты

storage_fast() {
    echo "${FAST_STORAGE:-/mnt/shotcut}"
}

storage_slow() {
    echo "${SLOW_STORAGE:-/mnt/storage}"
}

storage_backup() {
    echo "${BACKUP_STORAGE:-/mnt/backups/}"
}
