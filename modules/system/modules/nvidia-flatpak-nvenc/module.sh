#!/usr/bin/env bash
# modules/system/modules/nvidia-flatpak-nvenc/module.sh

system_nvidia_flatpak_nvenc_run() {
    local sub="${1:-help}" scope="" branch="" remote=flathub arg
    if (( $# > 0 )); then shift; fi
    for arg in "$@"; do
        case "$arg" in
            --scope=*) scope="${arg#*=}"; [[ "$scope" != default ]] || scope=system
                [[ "$scope" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 2 ;;
            --branch=*) branch="${arg#*=}"; [[ "$branch" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 2 ;;
            --remote=*) remote="${arg#*=}"; [[ "$remote" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 2 ;;
            *) echo "[ERROR] unknown option: $arg"; return 2 ;;
        esac
    done
    case "$sub" in
        doctor) nvidia_flatpak_nvenc_doctor "$scope" "$branch" "$remote" ;;
        fix) nvidia_flatpak_nvenc_fix "$scope" "$branch" "$remote" ;;
        heal) nvidia_flatpak_nvenc_heal "$scope" "$branch" "$remote" ;;
        help|--help)
            echo "Remedia System NVIDIA-Flatpak-NVENC module"
            echo
            echo "Usage:"
            echo "  remedia system nvidia-flatpak-nvenc <command>"
            echo
            echo "Commands:"
            echo "  doctor"
            echo "  fix"
            echo "  heal"
            echo
            echo "Optional:"
            echo "  --scope=user|system|NAME --branch=BRANCH --remote=REMOTE"
            echo
            echo "Run as desktop user without sudo. Repair requires exact extension confirmation."
            ;;
        *)  echo "[ERROR] unknown NVIDIA Flatpak NVENC command: $sub"; return 2 ;;
    esac
}
