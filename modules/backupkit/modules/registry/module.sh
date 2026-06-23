#!/usr/bin/env bash
# modules/system/modules/user/module.sh 

backupkit_user_run() {
    local action="${1:-}"
    shift || true

    case "$action" in
        add)
            require_root || {
                echo "[SECURITY] root required"
                return 42
            }
            add_user_to_backupkit "$@"
            ;;
        remove)
            echo "Remedia Backupkit User module"
            echo
            local user="${1:-}"
            local purge="${1:-}"
            if [[ "$(registry_status "$user")" == "disabled" && "$purge" != "--purge" ]]; then
                echo "[INFO] user already disabled"
                return 0
            fi
            if [[ "$purge" != "--purge" ]]; then
                echo "[ERROR] remove requires --purge"
                echo
                echo "Usage:"
                echo "  remedia backupkit user remove <username> --purge"
                return 1
            fi
            require_root || {
                echo "[SECURITY] root required"
                return 42
            }
            remove_user_from_backupkit "$@"
            ;;
        enable)
            echo "Remedia Backupkit User module"
            echo
            local user="${1:-}"
            
            if [[ -z "$user" ]]; then

                echo "[ERROR] username required"
                echo
                echo "Usage:"
                echo "  remedia backupkit user enable <username>"
                return 1
            fi
            registry_set_status "$user" active
            echo "[INFO] user $user activated"
            ;;
        disable)
            echo "Remedia Backupkit User module"
            echo
            local user="${1:-}"
            
            if [[ -z "$user" ]]; then

                echo "[ERROR] username required"
                echo
                echo "Usage:"
                echo "  remedia backupkit user disable <username>"
                return 1
            fi
            registry_set_status "$user" disabled
            echo "[INFO] user $user disabled"
            ;;
        list)
            registry_list_users_numbered
            ;;   
        *)  
            echo "Remedia Backupkit User module"
            echo
            echo "[USER] unknown action: $action"
            echo
            echo "Usage:"
            echo "  remedia backupkit user <command>"
            echo
            echo "Commands:"
            echo "  list"
            echo "  add"             
            echo "  enable"
            echo "  disable"            
            echo "  remove"
            return 0
            ;;
    esac
}
