#!/usr/bin/env bash
# modules/backupkit/modules/firefox/module.sh 

backupkit_firefox_run() {
    local action="${1:-}"
    shift || true

    case "$action" in
        backup)
            if ! registry_has_user "$BK_USER"; then
                echo "[ERROR] user not registered in backupkit"
                exit 1
            fi
            backup_firefox "$@"
            ;;

        restore)
            restore_firefox "$@"
            ;;
        bookmarks-open)
            bookmarks_open "$@"
            ;;
        *)  
            echo "Remedia Backupkit Firefox module"
            echo
            echo "[FIREFOX] unknown action: $action"
            echo
            echo "Usage:"
            echo "  remedia backupkit firefox <command>"
            echo
            echo "Commands:"
            echo "  backup" 
            echo "  restore"
            echo "  bookmarks-open"
            return 0
            ;;
    esac
}
