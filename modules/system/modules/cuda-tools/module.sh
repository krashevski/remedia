#!/usr/bin/env bash
# modules/system/modules/cuda-tools/module.sh 

system_cuda_tools() {
    local action="${1:-}"
    shift || true

    case "$action" in
        install)
           if ! require_root; then
                echo "[SECURITY] root required"
                return 42
            fi
            cuda_tools_install
            ;;

        remove)
            if ! require_root; then
                echo "[SECURITY] root required"
                return 42
            fi
            cuda_tools_remove
            ;;
        
        check)
            cuda_tools_check
            ;;
        *)  
            echo "Remedia System CUDA-TOOLKIT module"
            echo
            echo "[CUDA-TOOLS] unknown action: $action"
            echo
            echo "Usage:"
            echo "  remedia system cuda-tools <command>"
            echo
            echo "Commands:"
            echo "  install" 
            echo "  remove"
            echo "  check"
            return 0
            ;;
    esac
}
