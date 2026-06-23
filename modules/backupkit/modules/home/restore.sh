#!/usr/bin/env bash
# modules/backupkit/modules/home/restore.sh

resolve_snapshot_id() {
    local id="${1:-latest}"

    if [[ "$id" == "latest" ]]; then
        id="$(find_best_parent || find_latest_snapshot || true)"
    fi

    [[ -z "$id" ]] && return 1
    [[ -d "$SNAPSHOT_ROOT/$id/snapshot" ]] || return 1

    echo "$id"
}

auto_restore() {
    local id="$1"
    local meta="$SNAPSHOT_ROOT/$id/meta.json"

    [[ -f "$meta" ]] || {
        echo "[ERROR] meta.json not found: $id"
        return 1
    }

    log_step "auto-detect restore mode for $id"

    if meta_has_archive "$meta"; then
        log_step "mode: no-regression (snapshot + archive)"
        backupkit_restore_no_regression "$id"
    else
        log_step "mode: snapshot only"
        backupkit_restore_snapshot "$id"
    fi
}

restore_dispatch() {
    case "$1" in
        snapshot) backupkit_restore_snapshot "$2" ;;
        no-regression) backupkit_restore_no_regression "$2" ;;
        *) echo "[ERROR] unknown mode: $1"; return 1 ;;
    esac
}

restore_snapshot() {
    local id="$1"

    local chain=()

    while [[ -n "$id" ]]; do
        chain+=("$id")
        id="$(get_parent "$id")"
    done

    for ((i=${#chain[@]}-1; i>=0; i--)); do
        rsync -a "$SNAPSHOT_ROOT/${chain[$i]}/snapshot/" "$HOME/"
    done
}

backupkit_restore() {
    echo "Backupkit Home module"
    echo
    local mode="${1:-auto}"
    local id="${2:-latest}"

    id="$(resolve_snapshot_id "$id")" || return 1
    
    assert_user_owns_path "$snapshot_dir"

    [[ "$mode" == "auto" ]] && {
        auto_restore "$id"
        return
    }

    restore_dispatch "$mode" "$id"
}

