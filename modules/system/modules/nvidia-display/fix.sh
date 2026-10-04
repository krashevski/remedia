#!/usr/bin/env bash
# modules/system/modules/nvidia-display/fix.sh

nvidia_display_fix() {
    local code answer

    echo "Remedia System Nvidia-display module"
    echo

    if nvidia_display_doctor; then
        echo
        echo '[FIX] no driver repair indicated'
        return 0
    else code=$?; fi
    if (( code != 20 )) || [[ "$NVD_ACTION" != install_matching_module ]]; then
        echo
        echo "[POLICY] no automatic recovery for diagnosis $code"
        return "$code"
    fi
    echo '[PLAN] APT simulation (no changes)'
    if nvidia_display_simulate; then :; else return $?; fi
    # Preserve the Remedia root-required contract. Re-exec repeats diagnostics;
    # consent is requested only in the privileged invocation, never carried over.
    if declare -F require_root >/dev/null; then
        if require_root; then :; else return 42; fi
    elif (( EUID != 0 )); then
        return 42
    fi
    printf '\nRecovery plan:\n  apt-get --no-remove install %q\n  depmod -a %q\n  modprobe nvidia\n' \
        "$NVD_PACKAGE=$NVD_CANDIDATE" "$NVD_KERNEL"
    echo 'This changes system packages and loads the NVIDIA module. No reboot is performed.'
    echo "To confirm, type the exact package name: $NVD_PACKAGE"
    if ! read -r answer; then echo '[CANCELLED] no confirmation'; return 1; fi
    if [[ "$answer" != "$NVD_PACKAGE" ]]; then echo '[CANCELLED] no changes applied'; return 1; fi
    # A kernel change would invalidate the reviewed plan.
    [[ "$(uname -r)" == "$NVD_KERNEL" ]] || { echo '[POLICY] running kernel changed'; return 1; }
    if apt-get --no-remove install "$NVD_PACKAGE=$NVD_CANDIDATE"; then :; else return $?; fi
    if depmod -a "$NVD_KERNEL"; then :; else return $?; fi
    if modprobe nvidia; then :; else
        code=$?
        echo
        echo '[FAIL] modprobe failed; investigate Secure Boot and kernel logs'
        return "$code"
    fi
    echo
    echo '[FIX] package/module recovery commands completed'
    return 0
}
