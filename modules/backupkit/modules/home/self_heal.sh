#!/usr/bin/env bash
# backupkit/modules/home/self_heal.sh

set -euo pipefail

bk_log() {
    echo "[HEAL] $*"
}

get_snapshots_sorted() {
    find "$SNAPSHOT_ROOT" -maxdepth 1 -mindepth 1 -type d \
        -printf "%f\n" 2>/dev/null | LC_ALL=C sort
}

validate_snapshot() {
    local snap="$1"

    [[ -d "$SNAPSHOT_ROOT/$snap/snapshot" ]] || return 1
    [[ -f "$SNAPSHOT_ROOT/$snap/meta.json" ]] || return 1

    return 0
}

repair_chain() {
    bk_log "checking snapshot chain..."

    local snaps
    mapfile -t snaps < <(get_snapshots_sorted)

    local valid=()

    mkdir -p "$STATE_DIR"

    : > "$STATE_DIR/.broken_snapshots.tmp"

    for s in "${snaps[@]}"; do
        if validate_snapshot "$s"; then
            valid+=("$s")
        else
            bk_log "marking broken snapshot: $s"
            echo "$s" >> "$STATE_DIR/.broken_snapshots.tmp"
        fi
    done

    mv "$STATE_DIR/.broken_snapshots.tmp" "$STATE_DIR/.broken_snapshots"

    printf "%s\n" "${valid[@]}" > "$STATE_DIR/.snapshot_index"
}

fix_link_dest() {
    local prev="$1"

    if [[ -z "$prev" ]]; then
        return 1
    fi

#    local target="$BACKUP_ROOT/snapshots/$prev/snapshot"
    local target="$SNAPSHOT_ROOT/$prev/snapshot"

    if [[ ! -d "$target" ]]; then
        bk_log "broken link-dest detected: $prev → fixing"

        # fallback to previous valid snapshot
#        prev="$(ls -1 "$BACKUP_ROOT/snapshots" 2>/dev/null | LC_ALL=C sort | tail -n1 || true)"
        prev="$(ls -1 "$SNAPSHOT_ROOT" 2>/dev/null | LC_ALL=C sort | tail -n1 || true)"

#        if [[ -z "$prev" || ! -d "$BACKUP_ROOT/snapshots/$prev/snapshot" ]]; then
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

    repair_chain

    # recompute safe previous snapshot
    local prev
#    prev="$(ls -1 "$BACKUP_ROOT/snapshots" 2>/dev/null | LC_ALL=C sort | tail -n1 || true)"
    prev="$(ls -1 "$SNAPSHOT_ROOT" 2>/dev/null | LC_ALL=C sort | tail -n1 || true)"

    prev="$(fix_link_dest "$prev")"

    bk_log "self-heal done"
    echo "$prev"
}
