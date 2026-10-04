#!/usr/bin/env bash
# modules/system/modules/nvidia-display/module.sh

system_nvidia_display_run() {
    local sub="${1:-help}"
    if (( $# > 0 )); then shift; fi
    if (( $# > 0 )); then echo '[ERROR] this module accepts no target or --yes options'; return 2; fi
    case "$sub" in
        doctor) nvidia_display_doctor ;;
        fix) nvidia_display_fix ;;
        heal) nvidia_display_heal ;;
        help|--help)
            echo "Remedia System Nvidia-display module"
            echo
            echo "Usage:"
            echo "  remedia system nvidia-display <command>"
            echo
            echo "Commands:"
            echo "  doctor   (audits only)"
            echo "  fix      (require an explicit package confirmation)"
            echo "  heal"
            ;;
        *) echo "[ERROR] unknown NVIDIA display command: $sub"; return 2 ;;
    esac
}
