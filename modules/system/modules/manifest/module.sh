#!/usr/bin/env bash
# modules/system/modules/manifest/module.sh 

system_manifest_run() {
    local action="${1:-}"
    shift || true

    case "$action" in
        generate)
            system_manifest_generate "$@"
            ;;

        list)
            system_manifests_list "$@"
            ;;
        
        verify)
            system_doctor_verify "$@"
            ;;
        plan)
            system_doctor_plan "$@"
            ;;

        *)  
            echo "Remedia System Manifest module"
            echo
            echo "[MANIFEST] unknown action: $action"
            echo
            echo "Usage:"
            echo "  remedia system manifest <command>"
            echo
            echo "Commands:"
            echo "  generate" 
            echo "  list"
            echo "  verify"
            echo "  plan"
            return 0
            ;;
    esac
}
