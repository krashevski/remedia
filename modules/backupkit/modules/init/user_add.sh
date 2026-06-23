#!/usr/bin/env bash
# modules/backupkit/modules/init/user_add.sh 

init_user_storage() {
    local user="$1"
    local dir="$BACKUP_ROOT/user_data/$user"

    # уже существует → ок
    [[ -d "$dir" ]] && return 0

    mkdir -p "$dir" || {
        echo "[ERROR] failed to create user dir"
        return 1
    }

    chown "$user:backupkit" "$dir"
    chmod 2750 "$dir"

    mkdir -p "$dir/snapshots" "$dir/state"
    chown -R "$user:backupkit" "$dir"

    return 0
}

add_user_to_backupkit() {
    echo "Remedia Backupkit User module"
    echo
    runtime_require BK_USER
    runtime_require BACKUP_ROOT
    
    local user="${1:-}"

    if [[ -z "$user" ]]; then
        echo "[ERROR] username required"
        echo
        echo "Usage:"
        echo "  remedia backupkit user add <username>"
        return 1
    fi

    # 1. системная группа
    usermod -aG backupkit "$user" || {
        echo "[ERROR] failed to add user to group"
        return 1
    }

    # 2. registry
    registry_add_user "$user" || return 1

    # 3. storage (🔥 ВАЖНО)
    init_user_storage "$user" || return 1

    echo "[INFO] user $user added to backupkit"
}
