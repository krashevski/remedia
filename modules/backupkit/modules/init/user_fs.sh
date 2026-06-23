#!/usr/bin/env bash
# modules/backupkit/modules/init/user_fs.sh

ensure_user_fs() {
    local dir="$USER_ROOT"

    mkdir -p "$dir/snapshots" "$dir/state" || {
        echo "[ERROR] failed to init user fs"
        return 1
    }

    chown -R "$BK_USER:backupkit" "$dir" || true
}
