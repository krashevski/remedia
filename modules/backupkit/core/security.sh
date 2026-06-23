#!/usr/bin/env bash
# modules/backupkit/core/security.sh

assert_user_owns_path() {
    local path="$1"

    [[ -e "$path" ]] || {
        echo "[SECURITY] path does not exist: $path"
        exit 1
    }

    local owner
    owner="$(stat -c %U "$path")"

    if [[ "$owner" != "$BK_USER" ]]; then
        echo "[SECURITY] access denied: $path (owner=$owner, user=$BK_USER)"
        exit 1
    fi
}

assert_snapshot_access() {
    local id="$1"
    assert_user_owns_path "$SNAPSHOT_ROOT/$id"
}
