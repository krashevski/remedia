#!/usr/bin/env bash
# modules/mediasystem/module.sh

cmd_run() {
    echo "Remedia MediaSystem module"
    echo
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # если передан mode → используем его
    if [[ -n "${1:-}" ]]; then
        PIPELINE_MODE="$1"
    else
        # CLI интерактивный режим
        exec < /dev/tty

        while true; do
            echo "Select pipeline mode:"
            echo "1) safe"
            echo "2) standard"
            echo "3) full"
            echo
            echo "0) cancel"
            echo
            read -rp "Choice: " choice

            case "$choice" in
                1) PIPELINE_MODE="safe"; break ;;
                2) PIPELINE_MODE="standard"; break ;;
                3) PIPELINE_MODE="full"; break ;;
                0) return 0 ;;
                *) echo "Invalid option" ;;
            esac
        done
    fi

    export PIPELINE_MODE

    echo "[MediaSystem] mode: $PIPELINE_MODE"

    bash "$SCRIPT_DIR/bootstrap_pipeline.sh"
}

cmd_status() {
    echo "Remedia MediaSystem module"
    echo
    [[ "${REMEDIA_UI:-0}" == "1" ]] && echo "[OK]" || echo "[MediaSystem] status: OK"
}

cmd_mediasystem_doctor() {
    mediasystem_health_check
}

cmd_auto_help() {
    # module name вычисляется автоматически
    local module="mediasystem"
    remedia_module_help "$module"
}

register_module() {
    remedia_register "run" cmd_run
    remedia_register "doctor" cmd_mediasystem_doctor
    remedia_register "status" cmd_status
    remedia_register "help" cmd_auto_help
}

entry_module() {
    type remedia_run >/dev/null || {
        echo "[FATAL] remedia core not loaded"
        exit 1
    }
    
    local cmd="${1:-help}"
    shift || true
    remedia_run "$cmd" "$@"
}

register_module

