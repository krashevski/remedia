#!/usr/bin/env bash
# modules/system/ui/screens/users_home.sh

screen_cuda_tools() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                   ${COLOR_BOLD}${COLOR_CYAN} CUDA TOOLKIT ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "Module for controlling CUDA-Toolkit package"
        echo
        echo "1) CUDA toolkit install"
        echo "2) CUDA toolkit uninstall"
        echo "3) CUDA toolkit check"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Select [1-#]: " c

        case "$c" in
            1)            
                remedia system cuda-tools install
                ;;
            2) 
                remedia system cuda-tools remove
                ;;
            3) 
                remedia system cuda-tools check
                ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp "Press Enter..."
    done
}
