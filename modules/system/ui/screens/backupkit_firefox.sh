#!/usr/bin/env bash
# modules/system/ui/screens/backupkit_firefox.sh

screen_firefox() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                 ${COLOR_BOLD}${COLOR_CYAN} BACKUPKIT FIREFOX ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "1) Backup Firefox"
        echo "2) Restore Firefox"
        echo "3) Firefox bookmarks HTML file"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Choice [1-#]: " c

        case "$c" in
            1) remedia backupkit firefox backup || true ;;
            2) remedia backupkit firefox restore || true ;;
            3) remedia backupkit firefox bookmarks-open || true ;;
            0)
                return
                ;;
        esac
        
        read -rp "Press Enter..."
    done
}
