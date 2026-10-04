#!/usr/bin/env bash
# modules/system/modules/nvidia-display/policy.sh

# Audit data is refreshed on every invocation; no cached repair decisions.
nvidia_display_os_id() {
    ( . /etc/os-release; printf '%s\n' "${ID:-unknown}" ) 2>/dev/null || echo unknown
}

nvidia_display_collect() {
    NVD_KERNEL=unknown
    NVD_OS="$(nvidia_display_os_id)"
    NVD_VARIANT="" NVD_PACKAGE="" NVD_CANDIDATE="" NVD_ACTION=""
    NVD_MODULE="" NVD_LOADED=0 NVD_NOUVEAU=0 NVD_SMI_RC=127
    NVD_SMI="not run" NVD_SECURE_BOOT="unknown" NVD_GPU=unknown
    NVD_DRIVERS="" NVD_PREBUILT="" NVD_DKMS="" NVD_EXACT_INSTALLED=0
    NVD_TOOLS="" NVD_PACKAGES="" NVD_MODINFO_ERROR=""
    local tool packages name status version mods path vendor class
    for tool in uname dpkg-query apt-cache modinfo lsmod timeout; do
        command -v "$tool" >/dev/null 2>&1 || NVD_TOOLS+=" $tool"
    done
    if [[ -n "$NVD_TOOLS" ]]; then return 10; fi
    NVD_KERNEL="$(uname -r)" || { NVD_TOOLS="uname (failed)"; return 10; }
    if command -v lspci >/dev/null 2>&1; then
        if packages="$(lspci -Dn 2>/dev/null)"; then
            NVD_GPU=no
            if grep -Eq '^[^ ]+ 03[0-9a-fA-F]{2}: 10de:' <<< "$packages"; then NVD_GPU=yes; fi
        fi
    else
        for path in /sys/bus/pci/devices/*; do
            [[ -r "$path/vendor" && -r "$path/class" ]] || continue
            NVD_GPU="${NVD_GPU/unknown/no}"
            read -r vendor < "$path/vendor" || continue
            read -r class < "$path/class" || continue
            if [[ "$vendor" == 0x10de && "$class" == 0x03* ]]; then NVD_GPU=yes; break; fi
        done
    fi
    if ! packages="$(dpkg-query -W -f='${Package}|${db:Status-Status}|${Version}\n' \
            'nvidia-driver-*' 'linux-modules-nvidia-*' 'nvidia-dkms-*' 2>/dev/null)"; then
        # Unmatched globs cause dpkg-query to return nonzero; retained rows still matter.
        :
    fi
    while IFS='|' read -r name status version; do
        [[ "$status" == installed ]] || continue
        case "$name" in
            nvidia-driver-*|linux-modules-nvidia-*|nvidia-dkms-*)
                NVD_PACKAGES+="$name ($version)"$'\n' ;;
        esac
        if [[ "$name" =~ ^nvidia-driver-([0-9]+(-server)?(-open)?)$ ]]; then
            NVD_DRIVERS+="${BASH_REMATCH[1]}"$'\n'
        fi
        [[ "$name" != linux-modules-nvidia-* ]] || NVD_PREBUILT+="$name"$'\n'
        [[ "$name" != nvidia-dkms-* ]] || NVD_DKMS+="$name"$'\n'
    done <<< "$packages"
    if [[ -n "$NVD_DRIVERS" ]]; then
        local -a variants=()
        mapfile -t variants < <(printf '%s' "$NVD_DRIVERS" | sort -u)
        if (( ${#variants[@]} == 1 )); then
            NVD_VARIANT="${variants[0]}"
            NVD_PACKAGE="linux-modules-nvidia-$NVD_VARIANT-$NVD_KERNEL"
            if grep -Fxq "$NVD_PACKAGE" <<< "$NVD_PREBUILT"; then NVD_EXACT_INSTALLED=1; fi
            NVD_CANDIDATE="$(LC_ALL=C apt-cache policy "$NVD_PACKAGE" 2>/dev/null | \
                awk '/^[[:space:]]*Candidate:/ {print $2; exit}')"
            [[ "$NVD_CANDIDATE" != '(none)' ]] || NVD_CANDIDATE=""
        fi
    fi
    if NVD_MODULE="$(modinfo -k "$NVD_KERNEL" -F filename nvidia 2>/dev/null)"; then
        [[ -n "$NVD_MODULE" ]] || NVD_MODULE=""
    else
        NVD_MODULE=""
        NVD_MODINFO_ERROR="$(modinfo -k "$NVD_KERNEL" nvidia 2>&1 || true)"
    fi
    if ! mods="$(lsmod 2>/dev/null)"; then NVD_TOOLS="lsmod (failed)"; return 10; fi
    if grep -q '^nvidia ' <<< "$mods"; then NVD_LOADED=1; fi
    if grep -q '^nouveau ' <<< "$mods"; then NVD_NOUVEAU=1; fi
    # nvidia-smi may invoke nvidia-modprobe on some installations. Do not run it
    # when the module is absent from lsmod: the Doctor must not load modules.
    if (( NVD_LOADED == 1 )) && command -v nvidia-smi >/dev/null 2>&1; then
        if NVD_SMI="$(timeout 15s nvidia-smi 2>&1)"; then NVD_SMI_RC=0; else NVD_SMI_RC=$?; fi
    elif (( NVD_LOADED == 0 )); then
        NVD_SMI="skipped: NVIDIA module is not loaded (read-only audit)"
    else
        NVD_SMI="nvidia-smi command unavailable"
    fi
    if command -v mokutil >/dev/null 2>&1; then
        NVD_SECURE_BOOT="$(LC_ALL=C mokutil --sb-state 2>&1 || true)"
    fi
    return 0
}

nvidia_display_decide() {
    [[ -z "$NVD_TOOLS" ]] || return 10
    [[ "$NVD_GPU" != no ]] || return 0
    if (( NVD_LOADED == 1 )); then
        (( NVD_SMI_RC == 0 )) && return 0
        return 22
    fi
    [[ -z "$NVD_MODULE" ]] || return 21
    [[ "$NVD_OS" == ubuntu ]] || return 13
    [[ -n "$NVD_DRIVERS" ]] || return 11
    [[ -n "$NVD_VARIANT" ]] || return 12
    [[ "$NVD_GPU" == yes ]] || return 10
    [[ -z "$NVD_DKMS" ]] || return 14
    (( NVD_NOUVEAU == 0 )) || return 24
    (( NVD_EXACT_INSTALLED == 0 )) || return 23
    # Evidence that the system actually uses Ubuntu prebuilt modules.
    grep -Eq "^linux-modules-nvidia-${NVD_VARIANT}-[0-9]+\\." <<< "$NVD_PREBUILT" || return 15
    [[ -n "$NVD_CANDIDATE" ]] || return 16
    [[ "$NVD_KERNEL" =~ ^[a-zA-Z0-9.+_-]+$ ]] || return 10
    [[ "$NVD_CANDIDATE" =~ ^[a-zA-Z0-9.+:~_-]+$ ]] || return 10
    NVD_ACTION=install_matching_module
    return 20
}

nvidia_display_simulate() {
    local line package plan
    command -v apt-get >/dev/null 2>&1 || return 10
    if ! plan="$(LC_ALL=C apt-get --simulate --no-remove install \
            "$NVD_PACKAGE=$NVD_CANDIDATE" 2>&1)"; then
        printf '%s\n' "$plan"
        return 25
    fi
    printf '%s\n' "$plan"
    while IFS= read -r line; do
        case "$line" in
            Remv\ *) echo '[POLICY] package removal is forbidden'; return 25 ;;
            Inst\ *)
                package="${line#Inst }"; package="${package%% *}"
                # Refuse transitions that change driver/userspace/kernel/DKMS packages.
                case "$package" in
                    "$NVD_PACKAGE") ;;
                    linux-objects-nvidia-*)
                        case "$package" in
                            "linux-objects-nvidia-$NVD_VARIANT-$NVD_KERNEL"|"linux-objects-nvidia-${NVD_VARIANT%-open}-$NVD_KERNEL") ;;
                            *) echo "[POLICY] unrelated module objects: $package"; return 25 ;;
                        esac ;;
                    "linux-signatures-nvidia-$NVD_KERNEL") ;;
                    *) echo "[POLICY] unexpected dependency change: $package"; return 25 ;;
                esac ;;
        esac
    done <<< "$plan"
    return 0
}
