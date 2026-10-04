#!/usr/bin/env bash
# modules/system/modules/nvidia-flatpak-nvenc/policy.sh

nvidia_flatpak_nvenc_scope_option() {
    case "$1" in
        user) printf '%s\n' --user ;;
        system|default) printf '%s\n' --system ;;
        *) [[ "$1" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 2
           printf '%s\n' "--installation=$1" ;;
    esac
}

nvidia_flatpak_nvenc_collect() {
    local requested_scope="${1:-}" requested_branch="${2:-}" requested_remote="${3:-flathub}"
    local tool rows row ref scope type app arch branch mods versions version remote_names
    NFP_USER="$(id -un)" NFP_TOOLS="" NFP_REASON="" NFP_ACTION=""
    NFP_VERSION="" NFP_HOST="not run" NFP_GL="not run" NFP_APP_REF=""
    NFP_SCOPE="" NFP_SCOPE_OPT="" NFP_ARCH="" NFP_BRANCH="" NFP_RUNTIME=""
    NFP_REF="" NFP_SHORT_REF="" NFP_INSTALLED=0 NFP_OTHER_SCOPES=""
    NFP_REMOTE="$requested_remote" NFP_REMOTE_RESULT="not queried" NFP_REMOTE_REF=""
    NFP_TEST="not run" NFP_TEST_RC=127 NFP_FRAMES=0 NFP_LOADED=0
    # Flatpak sandbox tests belong to the desktop user. System installation
    # authorization is handled by Flatpak/Polkit, never by sudo re-exec here.
    if [[ "$(id -u)" == 0 ]]; then
        NFP_REASON='Run this module as your desktop user, without sudo.'
        return 10
    fi
    for tool in flatpak nvidia-smi timeout lsmod; do
        command -v "$tool" >/dev/null 2>&1 || NFP_TOOLS+=" $tool"
    done
    if [[ -n "$NFP_TOOLS" ]]; then NFP_REASON="Missing tools:$NFP_TOOLS"; return 10; fi
    if ! mods="$(lsmod 2>/dev/null)"; then NFP_REASON='Cannot read loaded modules'; return 10; fi
    if ! grep -q '^nvidia ' <<< "$mods"; then
        NFP_REASON='Host NVIDIA module is not loaded; use nvidia-display doctor first.'
        NFP_HOST='nvidia-smi skipped to avoid implicit module loading'
        return 11
    fi
    NFP_LOADED=1
    if versions="$(timeout --kill-after=3s 15s nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1)"; then
        NFP_HOST="$versions"
    else
        NFP_HOST="$versions"; NFP_REASON='Host nvidia-smi failed; investigate host driver first'; return 11
    fi
    local -a unique_versions=()
    mapfile -t unique_versions < <(printf '%s\n' "$versions" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | sort -u)
    if (( ${#unique_versions[@]} != 1 )) || [[ ! "${unique_versions[0]:-}" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        NFP_REASON='Driver version is invalid or differs between GPUs'; return 12
    fi
    NFP_VERSION="${unique_versions[0]}"
    if ! NFP_GL="$(timeout --kill-after=3s 10s flatpak --gl-drivers 2>&1)"; then
        NFP_REASON='flatpak --gl-drivers failed'; return 10
    fi
    if ! rows="$(LC_ALL=C flatpak list --app --columns=application,arch,branch,installation 2>&1)"; then
        NFP_REASON="Cannot enumerate Flatpak installations: $rows"; return 10
    fi
    local -a matches=()
    while IFS=$'\t' read -r app arch branch scope; do
        [[ "$app" == org.shotcut.Shotcut ]] || continue
        ref="app/$app/$arch/$branch"
        [[ "$scope" != default ]] || scope=system
        [[ -z "$requested_scope" || "$scope" == "$requested_scope" ]] || continue
        [[ -z "$requested_branch" || "$branch" == "$requested_branch" ]] || continue
        matches+=("$ref"$'\t'"$scope")
    done <<< "$rows"
    if (( ${#matches[@]} == 0 )); then NFP_REASON='Shotcut not installed in the requested scope/branch'; return 13; fi
    if (( ${#matches[@]} != 1 )); then
        NFP_REASON="Multiple Shotcut installations/branches; select --scope and/or --branch. Found: ${matches[*]}"
        return 14
    fi
    IFS=$'\t' read -r NFP_APP_REF NFP_SCOPE <<< "${matches[0]}"
    IFS=/ read -r type app NFP_ARCH NFP_BRANCH <<< "$NFP_APP_REF"
    if [[ ! "$NFP_ARCH" =~ ^[a-zA-Z0-9_]+$ || ! "$NFP_BRANCH" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        NFP_REASON='Invalid Shotcut ref'; return 10
    fi
    NFP_SCOPE_OPT="$(nvidia_flatpak_nvenc_scope_option "$NFP_SCOPE")" || return 10
    if ! NFP_RUNTIME="$(flatpak info "$NFP_SCOPE_OPT" --show-runtime "$NFP_APP_REF" 2>&1)"; then
        NFP_REASON='Cannot resolve the selected Shotcut runtime'; return 10
    fi
    NFP_SHORT_REF="org.freedesktop.Platform.GL.nvidia-${NFP_VERSION//./-}//1.4"
    NFP_REF="runtime/org.freedesktop.Platform.GL.nvidia-${NFP_VERSION//./-}/$NFP_ARCH/1.4"
    # Inspect the exact architecture/branch in the chosen installation.
    if ref="$(flatpak info "$NFP_SCOPE_OPT" --show-ref "$NFP_REF" 2>/dev/null)" && [[ "$ref" == "$NFP_REF" ]]; then
        NFP_INSTALLED=1
    fi
    if rows="$(LC_ALL=C flatpak list --runtime --all --columns=application,arch,branch,installation 2>/dev/null)"; then
        while IFS=$'\t' read -r app arch branch scope; do
            ref="runtime/$app/$arch/$branch"
            if [[ "$ref" == "$NFP_REF" ]]; then NFP_OTHER_SCOPES+="$scope "; fi
        done <<< "$rows"
    fi
    return 0
}

nvidia_flatpak_nvenc_test() {
    if NFP_TEST="$(timeout --kill-after=5s 45s flatpak run "$NFP_SCOPE_OPT" \
            --arch="$NFP_ARCH" --branch="$NFP_BRANCH" --command=ffmpeg org.shotcut.Shotcut \
            -hide_banner -nostdin -nostats -progress pipe:1 \
            -f lavfi -i testsrc2=size=640x360:rate=30 \
            -t 1 -frames:v 30 -an -c:v h264_nvenc -f null - 2>&1)"; then
        NFP_TEST_RC=0
    else NFP_TEST_RC=$?; fi
    NFP_FRAMES="$(awk -F= '$1=="frame" {gsub(/[[:space:]]/,"",$2); n=$2} END {print n+0}' <<< "$NFP_TEST")"
    if (( NFP_TEST_RC == 0 && NFP_FRAMES == 30 )) && grep -qx 'progress=end' <<< "$NFP_TEST"; then return 0; fi
    return 1
}

nvidia_flatpak_nvenc_remote_check() {
    local names
    if ! names="$(LC_ALL=C flatpak remotes "$NFP_SCOPE_OPT" --columns=name 2>&1)"; then
        NFP_REMOTE_RESULT="$names"; return 21
    fi
    if ! grep -Fxq "$NFP_REMOTE" <<< "$names"; then
        NFP_REMOTE_RESULT="Remote '$NFP_REMOTE' is not configured in scope '$NFP_SCOPE'"
        return 21
    fi
    if NFP_REMOTE_RESULT="$(timeout --kill-after=3s 20s flatpak remote-info "$NFP_SCOPE_OPT" \
            --show-ref "$NFP_REMOTE" "$NFP_REF" 2>&1)"; then
        NFP_REMOTE_REF="$NFP_REMOTE_RESULT"
    else return 22; fi
    if [[ "$NFP_REMOTE_REF" != "$NFP_REF" ]]; then
        NFP_REMOTE_RESULT="Unexpected remote ref: $NFP_REMOTE_REF"; return 22
    fi
    return 0
}
