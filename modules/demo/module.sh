#!/usr/bin/env bash
# modules/demo/module.sh 

cmd_cinema() {
    demo_cinema_run "$@"
}
cmd_status() {
    echo "Remedia Demo module"
    echo ""
    echo "[MediaPanel] status: OK"
}

# auto-help
cmd_auto_help() {
    # module name вычисляется автоматически
    local module="demo"
    remedia_module_help "$module"
}

# REGISTRATION LAYER
register_module() {
    remedia_register "cinema" cmd_cinema
    remedia_register "status" cmd_status
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
