#!/usr/bin/env bash
# backupkit/modules/restore/modes.sh

set -euo pipefail

backupkit_restore_snapshot() {
    local id="$1"

    local snapshot
    snapshot="$(bk_snapshot_data_dir "$id")"

    [[ -d "$snapshot" ]] || {
        echo "[RESTORE] snapshot not found: $snapshot"
        return 1
    }

    log_step "snapshot restore"

    rsync -aHAX \
        --numeric-ids \
        --ignore-errors \
        "$snapshot/" "$HOME/"
}

backupkit_restore_no_regression() {
    local id="$1"

    local root
    root="$(bk_snapshot_dir "$id")"

    local snapshot
    snapshot="$(bk_snapshot_data_dir "$id")"

    local archive="$root/diff.tar.zst"

    log_step "no-regression restore"

    # 1. snapshot
    rsync -aHAX \
        --numeric-ids \
        --ignore-errors \
        --update \
        "$snapshot/" "$HOME/"

    # 2. archive
    if [[ -f "$archive" ]]; then
        log_step "restore from archive"

        local tmp
        tmp="$(mktemp -d)"

        tar -I zstd -xf "$archive" -C "$tmp"

        rsync -aHAX \
            --numeric-ids \
            --ignore-errors \
            --ignore-existing \
            "$tmp/" "$HOME/"

        rm -rf "$tmp"
    fi
    echo
}
