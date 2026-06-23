#!/usr/bin/env bash
# core/registry.sh

declare -gA REMEDIA_REGISTRY=()

remedia_register() {
    local cmd="$1"
    local fn="$2"

    # ❗ защита от пустых аргументов
    if [[ -z "$cmd" || -z "$fn" ]]; then
        echo "[FATAL] remedia_register requires cmd + fn"
        exit 1
    fi

    # ❗ проверка существования функции
    if ! declare -F "$fn" >/dev/null 2>&1; then
        echo "[FATAL] function '$fn' not found"
        exit 1
    fi

    # ❗ защита от дубля команд
    if [[ -n "${REMEDIA_REGISTRY[$cmd]:-}" ]]; then
        echo "[FATAL] command already registered: $cmd"
        exit 1
    fi

    REMEDIA_REGISTRY["$cmd"]="$fn"
}

remedia_list() {
    printf '%s\n' "${!REMEDIA_REGISTRY[@]}"
}
