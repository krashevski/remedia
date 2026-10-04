#!/usr/bin/env bash
# modules/system/modules/nvidia-flatpak-nvenc/heal.sh

nvidia_flatpak_nvenc_heal() {
    local code
    if nvidia_flatpak_nvenc_fix "$@"; then :; else return $?; fi
    echo '[HEAL] verify the selected Shotcut installation with a real encode'
    if nvidia_flatpak_nvenc_doctor "$NFP_SCOPE" "$NFP_BRANCH" "$NFP_REMOTE"; then
        echo '[HEAL] NVENC test passed; retry MediaPanel export'
        return 0
    else
        code=$?
        echo '[HEAL] NVENC recovery not verified; use libx264 CPU export'
        return "$code"
    fi
}
