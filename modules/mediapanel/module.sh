#!/usr/bin/env bash
#  modules/mediapanel/module.sh

cmd_ui() {
    echo "[MediaPanel] ui start"
    source "$MODULE_DIR/ui/ui.sh"
    main_menu
}

cmd_status() {
    echo "Remedia MediaPanel module"
    echo ""
    echo "[MediaPanel] status: OK"
}

cmd_doctor() {
    case "$1" in
        media)
            doctor_media
            ;;
    esac
}

# auto-help
cmd_auto_help() {
    # module name вычисляется автоматически
    local module="mediapanel"
    remedia_module_help "$module"
}

register_module() {
    remedia_register "ui" cmd_ui
    remedia_register "status" cmd_status
    remedia_register "help" cmd_auto_help
}

entry_module() {
    command -v remedia_run >/dev/null 2>&1 || {
        echo "[FATAL] remedia core not loaded"
        exit 1
    }
    
    local cmd="${1:-help}"
    shift || true
    remedia_run "$cmd" "$@"
}

register_module




