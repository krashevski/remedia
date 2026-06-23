#!/usr/bin/env bash
# modules/system/modules/home/fix.sh

home_fix() {
    local action="${1:-}"
    local user="${2:-}"

    echo "Remedia System Home module"
    echo
    
    if ! require_root; then
        return 42
    fi

    [[ -z "$action" || -z "$user" ]] && {
        echo "[ERROR] action + user required"
        return 1
    }

    source "$MODULE_DIR/modules/home/policy.sh"

    local path="/home/$user"

    home_policy_validate "$user" "$path" || return 1

    case "$action" in
        fix_owner)
            echo "[FIX] restoring ownership..."
            chown -R "$user:$user" "$path"
            ;;

        fix_permissions)
            echo "[FIX] restoring permissions..."

            chmod 755 "$path"
            find "$path" -type d -exec chmod 755 {} \;
            find "$path" -type f -exec chmod 644 {} \;

            ;;

        *)
            echo "[FIX] unknown action: $action"
            return 1
            ;;
    esac

    echo "[DOCTOR] [FIX] done"
}
