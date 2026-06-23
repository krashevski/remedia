#!/usr/bin/env bash
# modules/backupkit/modules/registry/user_remove.sh 

remove_user_from_backupkit() {
    echo "Remedia Backupkit User module"
    echo
    local user="${1:-}"   
    local purge="${2:-}"

    if [[ -z "$user" ]]; then
        echo "Remedia Backupkit User module"
        echo
        echo "[ERROR] username required"
        echo
        echo "Usage:"
        echo "  remedia backupkit user remove <username>"
        echo "  remedia backupkit user remove <username> --purge"
        return 1
    fi

    if [[ "$user" == "$BK_USER" ]]; then
        echo "[ERROR] cannot remove current user"
        return 1
    fi

    if ! registry_has_user "$user"; then
        echo "[ERROR] user not found"
        return 1
    fi

    local dir="$BACKUP_ROOT/user_data/$user"
    
    if [[ -d "$dir/snapshots" ]] && [[ "$purge" == "--purge" ]]; then
        echo "[WARN] user has snapshots!"
        read -rp "Confirm delete? (yes/no): " c
        [[ "$c" != "yes" ]] && return 1
    fi

    # 1. deactivate
    registry_disable_user "$user"
    echo "[INFO] user disabled"

    # 2. purge (optional)
    if [[ "$purge" == "--purge" ]]; then
        if [[ -d "$dir" ]]; then
            echo "[WARN] removing user data: $dir"
            rm -rf "$dir"
        fi

        registry_remove_user "$user"
        echo "[INFO] user fully removed"
    fi
}
