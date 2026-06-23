#!/usr/bin/env bash
# modules/system/modules/home/module.sh

system_home_run() {
    local sub="${1:-}"
    shift || true

    case "$sub" in
        doctor)           
            home_doctor "$@"
            ;;
        fix)
            local user="${1:-}"
            [[ -z "$user" ]] && {
                echo "[ERROR] user required"
                echo "Usage:" 
                echo "  remedia system home fix USER"
                return 1
            }

            # default действие
            home_fix "fix_owner" "$user"
            ;;
        heal) 
            home_heal "$@"
            ;;
        *)
            echo "Remedia System Home module"
            echo
            echo "Usage:" 
            echo "  remedia system home <command> USER"
            echo
            echo "Commands:"
            echo "  doctor" 
            echo "  fix      (manual repair)"
            echo "  heal"
            return 0
            ;;
    esac
}
