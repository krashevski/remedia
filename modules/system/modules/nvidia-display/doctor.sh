#!/usr/bin/env bash
# modules/system/modules/nvidia-display/doctor.sh

nvidia_display_doctor() {
    local code=0
    if nvidia_display_collect; then
        if nvidia_display_decide; then code=0; else code=$?; fi
    else
        code=$?
    fi
    NVD_CODE=$code
    NVD_FAIL=0 NVD_WARN=0
    echo
    echo '[NVIDIA DISPLAY] Doctor (audit only)'
    printf 'Kernel: %s\nOS: %s\nNVIDIA display hardware: %s\n' "$NVD_KERNEL" "$NVD_OS" "$NVD_GPU"
    printf 'Installed driver branch/variant: %s\n' "${NVD_VARIANT:-unresolved}"
    printf 'Installed NVIDIA packages:\n%s\n' "${NVD_PACKAGES:-none detected}"
    printf 'Module for running kernel: %s\nLoaded: %s\nnouveau loaded: %s\n' \
        "${NVD_MODULE:-not found}" "$NVD_LOADED" "$NVD_NOUVEAU"
    printf 'Secure Boot: %s\n' "$NVD_SECURE_BOOT"
    printf 'Matching package: %s\nAPT candidate: %s\n' "${NVD_PACKAGE:-unresolved}" "${NVD_CANDIDATE:-none}"
    printf 'nvidia-smi (exit %s):\n%s\n' "$NVD_SMI_RC" "$NVD_SMI"
    echo
    case "$code" in
        0)
            if [[ "$NVD_GPU" == no ]]; then echo '[SKIP] no NVIDIA display device detected'
            else echo '[DOCTOR][OK] NVIDIA driver responds; display resolution still needs desktop verification'; fi ;;
        10) echo "[DOCTOR][WARN] incomplete diagnostics / hardware detection. Missing or failed tools:$NVD_TOOLS" ;;
        11) echo '[DOCTOR][WARN] installed NVIDIA driver branch is not known' ;;
        12) echo '[DOCTOR][WARN] multiple installed driver variants; no automatic selection' ;;
        13) echo '[DOCTOR][WARN] automatic repair applies only to Ubuntu' ;;
        14) echo '[DOCTOR][WARN] DKMS detected; diagnose its build/signing state manually' ;;
        15) echo '[DOCTOR][WARN] no evidence of prebuilt modules for the installed driver variant' ;;
        16) echo '[DOCTOR][WARN] no matching APT candidate; check repositories and driver packages' ;;
        20) echo '[DOCTOR][FAIL] missing module for running kernel; matching package is available'
            echo '[DOCTOR][PLAN] request Heal explicitly to review and confirm recovery' ;;
        21) echo '[DOCTOR][FAIL] module exists but is not loaded; inspect actual load errors and Secure Boot' ;;
        22) echo '[DOCTOR][FAIL] module loaded but nvidia-smi failed; inspect NVML versions and kernel logs' ;;
        23) echo '[DOCTOR][FAIL] matching package already installed but module unavailable; manual investigation required' ;;
        24) echo '[DOCTOR][WARN] nouveau loaded; automatic driver replacement/unloading is forbidden' ;;
        *) echo "[DOCTOR][WARN] unexpected diagnosis code: $code" ;;
    esac
    if (( code >= 20 && code != 24 )); then NVD_FAIL=1
    elif (( code != 0 )); then NVD_WARN=1; fi
    if (( code != 0 )); then
        [[ -z "$NVD_MODINFO_ERROR" ]] || printf '%s\n' "$NVD_MODINFO_ERROR"
        echo 'Kernel log check: journalctl -k -b --no-pager | grep -Ei "nvidia|NVRM|secure|verification|key"'
        echo 'Log access may require administrator privileges; Doctor does not request them.'
    fi
    echo 'On GNOME/Wayland verify modes in desktop Display settings; xrandr alone is insufficient.'
    return "$code"
}
