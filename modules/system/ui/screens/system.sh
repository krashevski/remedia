#!/usr/bin/env bash
# modules/system/ui/screens/system.sh

screen_system() {
    clear
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "                 ${COLOR_BOLD}${COLOR_CYAN} REMEDIA SYSTEM ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    render_header
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_module "system" remedia system status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cmd_system_doctor
    echo
    echo "Module for monitoring the state of the Remedia system and treatment"
    echo
    echo "1) Man pages"
    echo "2) Users home"
    echo "3) Create symlinks for user big directories"
    echo "4) DPKG system upgrade"
    echo "5) CUDA tollkit"
    echo "6) Manifest"
    echo
    echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
    echo
    read -rp "Select [1-#]: " c
    
    case "$c" in
        1) screen_man ;;
        2) screen_usres_home ;;
        3) system_symlinks_run ;; 
        4) screen_dpkg ;;
        5) screen_cuda_tools ;;
        6) screen_manifest ;;
        0) return ;;
        *) echo "Invalid option" ;;
    esac
}
