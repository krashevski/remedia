#!/usr/bin/env bash
# modules/backupkit/modules/home/verify.sh

verify_backup() {
    echo "Backupkit Home module"
    echo
    local id="$1"

    assert_user_owns_path "$SNAPSHOT_ROOT/$id"

    [[ -f "$SNAPSHOT_ROOT/$id/meta.json" ]] || {
        echo "[BROKEN] missing meta: $id"
        return 1
    }

    [[ -d "$SNAPSHOT_ROOT/$id/snapshot" ]] || {
        echo "[BROKEN] missing snapshot: $id"
        return 1
    }

    echo "[VERIFY] OK: $id"
}

verify_all_backups() {
    local id
    local latest

    latest="$(get_latest_snapshot || true)"

    [[ -z "$latest" ]] && {
        echo "[VERIFY] no graph"
        return 0
    }

    verify_graph "$latest"
}
