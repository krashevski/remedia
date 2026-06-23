#!/usr/bin/env bash
# modules/system/ui/ui.sh 

main_menu() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "             ${COLOR_BOLD}${COLOR_CYAN} REMEDIA SYSTEM CENTER ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        render_status_block
        echo ""
        echo "1) Remedia help"
        echo "2) Remedia global doctor"
        echo "3) System"
        echo "4) MediaSystem"
        echo "5) MediaPanel"
        echo "6) Backupkit"
        echo "7) Demo cinema"
        echo
        echo -e "${COLOR_YELLOW}0) Exit${COLOR_RESET}"
        echo 
        read -rp "Select [1-#]: " choice

        case "$choice" in
            1) remedia_help ;;
            2) remedia doctor ;;
            3) screen_system ;;
            4) screen_mediasystem_run ;;
            5) remedia mediapanel ui ;;
            6) screen_backupkit ;;
            7) screen_cinema ;;
            0) exit 0 ;;
            *) echo "Invalid" ;;
        esac

        read -rp "Press Enter..."
    done
}
