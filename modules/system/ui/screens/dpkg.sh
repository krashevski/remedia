#!/usr/bin/env bash
# modules/system/ui/screens/users_home.sh

screen_dpkg() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "            ${COLOR_BOLD}${COLOR_CYAN} DPKG SYSTEM UPGRRADE ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "Diagnosing and healing dpkg systen upgrade"
        echo
        echo "1) DPKG system upgrade doctor"
        echo "2) Fixing dpkg state"
        echo "3) DPKG heal"
        echo "4) Upgrade systen"
        echo "5) Full upgrade systen"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Select [1-#]: " c

        case "$c" in
            1) 
                dpkg_doctor "@" 
                ;;
            2) 
                dpkg_fix "@" 
                ;;
            3) 
                dpkg_heal "@" 
                ;;
            4) 
                dpkg_upgrade "@" 
                ;;
            5) 
                dpkg_full_upgrade "@" 
                ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp "Press Enter..."
    done
}
