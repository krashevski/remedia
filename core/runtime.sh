#!/usr/bin/env bash
# core/runtime.sh 

runtime_boot() {    
    [[ "${RUNTIME_READY:-0}" == "1" ]] && return 0
    export RUNTIME_READY=1

    # ❗ ТОЛЬКО ОБЩИЕ ПЕРЕМЕННЫЕ
    [[ -n "${PROJECT_DIR:-}" ]] || exit 1
    [[ -n "${LOG_DIR:-}" ]] || exit 1
    [[ -n "${LOG_FILE:-}" ]] || exit 1
}

remedia_call() {
    remedia_dispatch "$@"
}

remedia_run() {
    local cmd="${1:-}"
    shift || true

    [[ -z "$cmd" ]] && cmd="help"

    local fn="${REMEDIA_REGISTRY[$cmd]:-}"

    if [[ -z "$fn" ]]; then
        echo "[ERROR] Unknown command: $cmd"
        cmd_auto_help
        return 1
    fi

    "$fn" "$@"
    return $?
}

