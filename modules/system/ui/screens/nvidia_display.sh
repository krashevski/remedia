#!/usr/bin/env bash
# modules/system/ui/screens/nvidia_display.sh

screen_nvidia_display() {
    local choice code
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                  ${COLOR_BOLD}${COLOR_CYAN} NVIDIA DISPLAY ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo
        echo 'Module for diagnosing and healing NVIDIA kernel-module state'
        echo
        echo '1) NVIDIA display doctor'
        echo '2) NVIDIA display heal'
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        if ! read -rp 'Select [1-2]: ' choice; then return 0; fi
        case "$choice" in
            1|2)
                local action=doctor
                [[ "$choice" != 2 ]] || action=heal
                if remedia system nvidia-display "$action"; then code=0; else code=$?; fi
                echo "[NVIDIA DISPLAY] exit code: $code" ;;
            0) return 0 ;;
            *) echo 'Invalid option' ;;
        esac
        read -rp 'Press Enter...' choice || return 0
    done
}
