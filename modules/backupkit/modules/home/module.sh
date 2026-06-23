#!/usr/bin/env bash
# modules/backupkit/modules/home/module.sh

backupkit_home_run() {
    local action="${1:-}"
    shift || true

    case "$action" in
        backup)
            if ! registry_has_user "$BK_USER"; then
                echo "[ERROR] user not registered in backupkit"
                exit 1
            fi
            self_heal_before_backup || true
            backupkit_backup "$@"
            ;;
        restore)
            backupkit_restore "$@"
            ;;
        verify)
            local mode="${1:-}"

            # resolve latest safely
            if [[ -z "$mode" ]]; then
                if declare -F find_latest_snapshot >/dev/null; then
                mode="$(find_latest_snapshot || true)"
            fi

            echo "[INFO] no id → using latest: $mode"
            fi

            # bootstrap state
            if [[ -z "$mode" ]]; then
                echo "[VERIFY] no snapshots found (bootstrap state)"
                return 0
            fi

            # all graph verify
            if [[ "$mode" == "--all" ]]; then
                verify_all_backups
                return $?
            fi

            verify_backup "$mode"
            ;;
        doctor)
            backupkit_doctor "$@"
            ;;
        garbage)
            backupkit_gc "$@"
            ;;   
        *)  
            echo "Remedia BackupKit Home module"
            echo
            echo "[HOME] unknown action: $action"
            echo
            echo "Usage:"
            echo "  remedia backupkit home <command> [options]"
            echo
            echo "Commands:"
            echo "  backup" 
            echo "  restore"
            echo "  verify"
            echo "  doctor"
            echo "  garbage"
            echo ""
            echo "Options:"
            echo "  doctor --repair    Check and attempt auto-repair"
            return 0
            ;;
    esac
}
