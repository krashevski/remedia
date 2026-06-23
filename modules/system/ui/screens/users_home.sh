#!/usr/bin/env bash
# modules/system/ui/screens/users_home.sh

screen_usres_home() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                  ${COLOR_BOLD}${COLOR_CYAN} USERS HOME ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "Module for diagnosing and healing user home directory state"
        echo
        echo "1) Users home doctor"
        echo "2) Users home heal"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Select [1-#]: " c

        case "$c" in
            1) 
                user="$(ui_input "Enter user")"
                home_doctor "$user" 
                ;;
            2) 
                user="$(ui_input "Enter user")"
                home_heal "$user" 
                ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp "Press Enter..."
    done
}
