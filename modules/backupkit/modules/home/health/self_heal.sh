#!/usr/bin/env bash
# backupkit/modules/home/self_heal.sh

set -euo pipefail

bk_log() {
    echo "[HEAL] $*" >&2
}

get_snapshots_sorted() {
    find "$SNAPSHOT_ROOT" -maxdepth 1 -mindepth 1 -type d \
        -printf "%f\n" \
        | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$' \
        | LC_ALL=C sort
}


validate_snapshot() {
    local snap="$1"
    [[ -d "$SNAPSHOT_ROOT/$snap/snapshot" ]]
}

is_valid_snapshot() {
    local id="$1"
    [[ -d "$SNAPSHOT_ROOT/$id" ]] || return 1
    [[ -d "$SNAPSHOT_ROOT/$id/snapshot" ]] || return 1
    [[ -f "$SNAPSHOT_ROOT/$id/meta.json" ]] || return 1
    return 0
}

fix_link_dest() {
    local prev="$1"

    local target="$SNAPSHOT_ROOT/$prev/snapshot"

    if [[ ! -d "$target" ]]; then
        bk_log "broken link-dest detected: $prev → fixing"

        # fallback to previous valid snapshot
        prev="$(get_last_valid_snapshot || true)"

        if [[ -z "$prev" ]]; then
            prev="$(ls -1 "$SNAPSHOT_ROOT" 2>/dev/null | LC_ALL=C sort | tail -n 1 || true)"
        fi

        if [[ -z "$prev" || ! -d "$SNAPSHOT_ROOT/$prev/snapshot" ]]; then
            bk_log "no valid base snapshot found → disabling link-dest"
            echo ""
            return 0
        fi
    fi

    echo "$prev"
}

self_heal_before_backup() {
    bk_log "starting self-heal..."

    repair_chain   # только filesystem cleanup

    local prev
    prev="$(get_last_valid_snapshot || true)"

    echo "$prev"
}
