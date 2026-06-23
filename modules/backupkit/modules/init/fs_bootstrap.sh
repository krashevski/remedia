#!/usr/bin/env bash
# core/fs_bootstrap.sh - chmod/chown/mkdir root-level

init_user_fs() {
    local user_dir="$USER_ROOT"

    mkdir -p "$user_dir/snapshots" "$user_dir/state"
    chown "$BK_USER:backupkit" "$user_dir"
    chmod 2750 "$user_dir"
}
