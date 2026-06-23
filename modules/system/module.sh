#!/usr/bin/env bash
# modules/system/module.sh 

cmd_center_ui() {
#    echo "[SYSTEM] running diagnostics..."
    main_menu
}

# COMMAND LAYER (HEADLESS)
cmd_status() {
    echo "Remedia System module"
    echo
    echo "[REMEDIA] [SYSTEM] status OK"
}

cmd_symlinks() {
    echo "Remedia System module"
    echo
    system_symlinks_run "$@"
}

cmd_system_doctor() {
    system_diagnostics
}

cmd_system_man() {
    log_debug "[DEBUG] HIT3 cmd_system_man"
    system_man_run "$@"
}

cmd_system_home() {
    system_home_run "$@"
}

cmd_system_dpkg() {
    system_dpkg_run "$@"
}

cmd_manifest() {
    local action="${1:-}"
    shift || true

    system_manifest_run "$action" "$@"
}

cmd_cuda_tools() {
    local action="${1:-}"
    shift || true

    system_cuda_tools "$action" "$@"
}

# auto-help
cmd_auto_help() {
    # module name вычисляется автоматически
    local module="system"
    remedia_module_help "$module"
}

# REGISTRATION LAYER
register_module() {
    remedia_register "center" cmd_center_ui
    remedia_register "status" cmd_status
    remedia_register "symlinks" cmd_symlinks
    remedia_register "man" cmd_system_man
    remedia_register "home" cmd_system_home
    remedia_register "dpkg" cmd_system_dpkg
    remedia_register "manifest" cmd_manifest
    remedia_register "doctor" cmd_system_doctor
    remedia_register "cuda-tools" cmd_cuda_tools
    remedia_register "help" cmd_auto_help
}


# ENTRY POINT
entry_module() {
    command -v remedia_run >/dev/null 2>&1 || {
        echo "[FATAL] remedia core not loaded"
        exit 1
    }
    log_debug "[DEBUG] HIT1 entry_module"
    local cmd="${1:-help}"
    shift || true

    remedia_run "$cmd" "$@"
}

register_module
