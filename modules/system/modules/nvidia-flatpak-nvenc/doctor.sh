#!/usr/bin/env bash
# modules/system/modules/nvidia-flatpak-nvenc/doctor.sh

nvidia_flatpak_nvenc_doctor() {
    local code=0
    NFP_FAIL=0 NFP_WARN=0
    if nvidia_flatpak_nvenc_collect "$@"; then
        # Encode even when same-scope info is missing: a visible cross-scope
        # extension may work. The real encode is the final readiness check.
        if nvidia_flatpak_nvenc_test; then
            code=0
            NFP_REASON='Real NVENC encode succeeded: 30 frames at 640x360'
        elif (( NFP_INSTALLED == 1 )); then
            code=23
            NFP_REASON='Matching extension installed but encode failed; no blind reinstall'
        elif ! grep -Fwq "nvidia-${NFP_VERSION//./-}" <<< "$NFP_GL"; then
            code=24
            NFP_REASON='Required GL driver is not active in Flatpak; installation alone is not justified'
        elif nvidia_flatpak_nvenc_remote_check; then
            code=20
            NFP_ACTION=install_exact_extension
            NFP_REASON='Encode failed and matching extension is missing in Shotcut scope; exact remote ref available'
        else
            code=$?
            NFP_REASON='Matching extension could not be confirmed in the configured remote'
        fi
    else code=$?; fi
    NFP_CODE=$code
    echo
    echo '[NVIDIA FLATPAK NVENC] Doctor (no package/override changes)'
    printf 'Desktop user: %s\nLoaded NVIDIA module: %s\nHost driver query:\n%s\n' "$NFP_USER" "$NFP_LOADED" "$NFP_HOST"
    printf 'Driver version: %s\nFlatpak active GL drivers:\n%s\n' "${NFP_VERSION:-unknown}" "$NFP_GL"
    printf 'Shotcut ref: %s\nInstallation scope: %s\nRuntime: %s\n' \
        "${NFP_APP_REF:-unresolved}" "${NFP_SCOPE:-unresolved}" "${NFP_RUNTIME:-unresolved}"
    printf 'Required extension: %s\nExact full ref: %s\nInstalled in selected scope: %s\n' \
        "${NFP_SHORT_REF:-unresolved}" "${NFP_REF:-unresolved}" "$NFP_INSTALLED"
    printf 'Matching extension found in scopes: %s\nRemote: %s\nRemote check: %s\n' \
        "${NFP_OTHER_SCOPES:-none detected}" "$NFP_REMOTE" "$NFP_REMOTE_RESULT"
    printf 'NVENC test: exit=%s frames=%s/30\n%s\n' "$NFP_TEST_RC" "$NFP_FRAMES" "$NFP_TEST"
    if (( code == 0 )); then
        echo
        echo "[DOCTOR][OK] $NFP_REASON"
        echo 'Retry the actual MediaPanel export; project/filter errors are outside this short test.'
    else
        if (( code >= 20 )); then NFP_FAIL=1; else NFP_WARN=1; fi
        echo
        echo "[DIAGNOSIS $code] $NFP_REASON"
        echo '[FALLBACK] MediaPanel CPU export: libx264'
        if (( code == 20 )); then echo '[PLAN] select Heal explicitly to review and confirm installation'; fi
    fi
    return "$code"
}
