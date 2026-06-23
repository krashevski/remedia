#!/usr/bin/env bash
# modules/system/modules/nan/module.sh
          
system_man_run() {
    local action="${1:-}"
    shift || true

    case "$action" in
        install)
            log_debug "[DEBUG] HIT4 system_man_run"
            if ! require_root; then
                echo "[SECURITY] root required"
                return 42
            fi
            man_install "$@"
            return $?
            ;;
        doctor)
            man_doctor "$@"
            return $?   # 🔥 ВАЖНО
            ;;
        
        open)
            man_open "$@"
            return $?   # 🔥 ВАЖНО
            ;;

        *)  
            echo "Remedia System Man module"
            echo
            echo "Usage:"
            echo "  remedia system man <command>"
            echo
            echo "Commands:"
            echo "  install" 
            echo "  doctor"
            echo "  open"
            return 0
            ;;
    esac
}
