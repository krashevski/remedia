#!/usr/bin/env bash
# core/debug.sh 

print_stack_trace() {
    [[ "${REMEDIA_LOG_LEVEL:-INFO}" == "DEBUG" ]] || return 0

    local i=0
    local frame

    echo "[STACK TRACE]"

    while true; do
        frame="$(caller "$i" 2>/dev/null)" || break
        [[ -z "$frame" ]] && break

        local line func file
        read -r line func file <<< "$frame"

        printf "  #%d %s:%s → %s()\n" "$i" "$file" "$line" "$func"

        ((i++))
    done
}
