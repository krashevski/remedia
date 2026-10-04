#!/usr/bin/env bash
# modules/system/modules/nvidia-display/heal.sh

nvidia_display_heal() {
    local code
    if nvidia_display_fix; then :; else
        code=$?
        return "$code"
    fi
    echo
    echo '[HEAL] re-check'
    if nvidia_display_doctor; then
        echo
        echo '[HEAL] verify the expected resolution in desktop settings.'
        echo '[HEAL] reboot at a convenient time, then run Doctor again to verify persistence.'
        return 0
    else
        code=$?
        echo
        echo "[HEAL] recovery is not verified (diagnosis $code)"
        return "$code"
    fi
}
