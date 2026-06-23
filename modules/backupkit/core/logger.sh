#!/usr/bin/env bash
# backupkit/core/logger.sh

log() {
    echo "[BACKUPKIT] $*" >&2
}

log_step() {
    echo "[BACKUPKIT][STEP] $*" >&2
}
