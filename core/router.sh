#!/usr/bin/env bash
# core/router.sh

run_with_escalation() {
    log_debug "[DEBUG] ENTER ESCALATION"

    "$@" || {
        local code=$?
        log_debug "[DEBUG] ESC EXIT: $code"

        if [[ $code -eq 42 ]]; then
            echo "[INFO] sudo required → restart pipeline"

            exec sudo "$(command -v remedia)" $ORIGINAL_ARGS_STR
        fi

        return $code
    }

    log_debug "[DEBUG] ESC EXIT: 0"
}

remedia_dispatch() {
    runtime_assert_ready || return 1

    local module="${1:-remedia}"
    shift || true
    
    # help ДО загрузки entry
    if [[ "${1:-}" == "--help" ]]; then
        remedia_module_help "$module"
        exit 0
    fi

    local entry="$REMEDIA_LIB/modules/$module/entry.sh"

    if [[ ! -f "$entry" ]]; then
        echo "[REMEDIA] Unknown module: $module"
        echo
        echo "Usage:"
        echo "  remedia <module>"
        echo ""
        echo "Modules:"

        for m in "$REMEDIA_MODULES"/*; do
            [[ -d "$m" ]] || continue
            echo "  $(basename "$m")"
        done

        return 127
    fi

    source "$entry"
    log_debug "[DEBUG] HIT0 remedia_dispatch"
    # 🔥 fallback: if module requires subcommands
    if declare -F entry_module >/dev/null; then
        run_with_escalation entry_module "$@"
    else        echo "[REMEDIA] Module has no entry point: $module"
        echo "Try: remedia $module <command>"
        return 2
    fi
}

