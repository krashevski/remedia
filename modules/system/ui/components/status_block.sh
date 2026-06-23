#!/usr/bin/env bash
# modules/system/components/status_block.sh

render_status_block() {  
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local failed=0
    export failed
    
    check_module "system" remedia system status
    check_module "mediasystem" remedia mediasystem status
    check_module "mediapanel"  remedia mediapanel status
    check_module "backupkit" remedia backupkit status
    
    if ! declare -F check_module >/dev/null; then
        echo "[FATAL] check_module not loaded"
        return 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $failed -eq 0 ]]; then
        echo -e "✔ REMEDIA HEALTH: ${COLOR_GREEN}OK${COLOR_RESET}"
    else
        echo -e "✖ REMEDIA HEALTH: ${COLOR_RED}DEGRADED${COLOR_RESET}"
        return 1
    fi
}
