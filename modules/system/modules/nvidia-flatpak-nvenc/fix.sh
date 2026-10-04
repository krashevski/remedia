#!/usr/bin/env bash
# modules/system/modules/nvidia-flatpak-nvenc/fix.sh

nvidia_flatpak_nvenc_fix() {
    local code answer version ref mods
    if nvidia_flatpak_nvenc_doctor "$@"; then
        echo '[FIX] NVENC already works; no installation required'
        return 0
    else code=$?; fi
    if (( code != 20 )) || [[ "$NFP_ACTION" != install_exact_extension ]]; then
        echo '[POLICY] no extension installation justified by this diagnosis'
        return "$code"
    fi
    printf '\nRecovery plan:\n  flatpak install %q --no-related --no-deps %q %q\n' \
        "$NFP_SCOPE_OPT" "$NFP_REMOTE" "$NFP_REF"
    echo 'The download can be large. Flatpak may request authorization for a system installation.'
    echo 'Type the exact short extension reference to confirm:'
    echo "$NFP_SHORT_REF"
    if ! read -r answer || [[ "$answer" != "$NFP_SHORT_REF" ]]; then
        echo '[CANCELLED] no installation performed'; return 1
    fi
    # Check mutable prerequisites again after consent, without changing the plan.
    if ! mods="$(lsmod 2>/dev/null)" || ! grep -q '^nvidia ' <<< "$mods"; then
        echo '[POLICY] NVIDIA module is no longer loaded'; return 11
    fi
    if ! version="$(timeout --kill-after=3s 15s nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1)"; then
        echo '[POLICY] host driver query failed after confirmation'; return 11
    fi
    version="$(printf '%s\n' "$version" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u)"
    if [[ "$version" != "$NFP_VERSION" ]]; then echo '[POLICY] loaded driver changed; run Doctor again'; return 12; fi
    if ! ref="$(flatpak info "$NFP_SCOPE_OPT" --show-ref "$NFP_APP_REF" 2>/dev/null)" || [[ "$ref" != "$NFP_APP_REF" ]]; then
        echo '[POLICY] selected Shotcut installation changed'; return 13
    fi
    if nvidia_flatpak_nvenc_remote_check; then :; else return $?; fi
    if flatpak install "$NFP_SCOPE_OPT" --no-related --no-deps "$NFP_REMOTE" "$NFP_REF"; then
        echo '[FIX] exact extension installation completed'
        return 0
    else
        code=$?
        echo "[FAIL] Flatpak installation failed (code $code); use libx264 CPU export"
        return "$code"
    fi
}
