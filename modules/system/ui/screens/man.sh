#!/usr/bin/env bash
# modules/system/ui/screens/man.sh

screen_man() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                  ${COLOR_BOLD}${COLOR_CYAN} MAN SYSTEM ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "Module for managing man system lifecycle with diagnostics and recovery tools"
        echo
        echo "1) Install man pages"
        echo "2) Doctor"
        echo "3) Open users-home-restore"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Select [1-#]: " c

        case "$c" in
            1) remedia system man install ;;
            2) remedia system man doctor ;;
            3) remedia system man open users-home-restore ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp "Press Enter..."
    done
}
