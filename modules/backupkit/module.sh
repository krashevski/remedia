#!/usr/bin/env bash
# modules/backupkit/module.sh 

cmd_status() {
    echo "Remedia BackupKit module"
    echo
    echo "[BackupKit] status: OK"
}

cmd_init() {
    require_root || {
        echo "[SECURITY] root required"
        return 42
    }
    init_backupkit "$@"
}

cmd_user() {
   backupkit_user_run "$@"
}

cmd_home() {
    backupkit_home_run "$@"
}

cmd_firefox() {
    backupkit_firefox_run "$@"
}

# auto-help
cmd_auto_help() {
    # module name вычисляется автоматически
    local module="backupkit"
    remedia_module_help "$module"
}

register_module() {
    remedia_register "home" cmd_home
    remedia_register "status" cmd_status
    remedia_register "init" cmd_init 
    remedia_register "user" cmd_user 
    remedia_register "firefox" cmd_firefox
    remedia_register "help" cmd_auto_help
}

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
