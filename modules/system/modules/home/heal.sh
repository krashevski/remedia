#!/usr/bin/env bash
# modules/system/modules/home/heal.sh

home_map_code_to_action() {
    case "$1" in
        4) echo "fix_owner" ;;
        5) echo "fix_permissions" ;;
        *) return 1 ;;
    esac
}

home_heal() {
    local user="${1:-}"
    echo "Remedia System Home module"
    echo

    [[ -z "$user" ]] && {
        echo "[ERROR] user required"
        echo "Usage:" 
        echo "  remedia system home heal USER"
        return 1
    }

    source "$MODULE_DIR/modules/home/doctor.sh"
    source "$MODULE_DIR/modules/home/fix.sh"

    echo "[HEAL] running doctor..."

    if home_doctor "$user"; then
        echo "[DOCTOR] [HEAL] nothing to fix"
        return 0
    fi

    local code=$?

    action=$(home_map_code_to_action "$code") || {
        echo "[HEAL] no strategy"
        return 1
    }

    echo "[HEAL] applying action: $action"

    home_fix "$action" "$user"
    local fix_code=$?

    if [[ "$fix_code" -ne 0 ]]; then
        if [[ "$fix_code" -eq 42 ]]; then
            echo "[HEAL] root required for fix"
            return 42
        fi

        echo "[HEAL] fix failed (code=$fix_code)"
        return 1
    fi

    echo "[HEAL] re-check..."

    if home_doctor "$user"; then
        echo "[HEAL] success"
        return 0
    else
        echo "[HEAL] still broken"
        return 1
    fi
}
