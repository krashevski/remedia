#!/usr/bin/env bash
# modules/system/ui/screens/nvidia_flatpak_nvenc.sh

screen_nvidia_flatpak_nvenc() {
    local choice action code scope
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "               ${COLOR_BOLD}${COLOR_CYAN} NVIDIA FLATPAK NVENC ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo
        echo 'Module for diagnosing and healing NVENC in Shotcut Flatpak'
        echo '1) NVIDIA Flatpak NVENC doctor'
        echo '2) NVIDIA Flatpak NVENC heal'
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        if ! read -rp 'Select [1-2]: ' choice; then return 0; fi
        case "$choice" in
            1|2)
                action=doctor; [[ "$choice" != 2 ]] || action=heal
                if ! read -rp 'Shotcut scope [Enter=auto, user/system/installation name]: ' scope; then return 0; fi
                local -a options=()
                [[ -z "$scope" ]] || options+=("--scope=$scope")
                if remedia system nvidia-flatpak-nvenc "$action" "${options[@]}"; then code=0; else code=$?; fi
                echo "[NVIDIA FLATPAK NVENC] exit code: $code" ;;
            0) return 0 ;;
            *) echo 'Invalid option' ;;
        esac
        read -rp 'Press Enter...' choice || return 0
    done
}
