#!/usr/bin/env bash
# modules/system/ui/screens/backupkit_userhome.sh

screen_usershome() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "               ${COLOR_BOLD}${COLOR_CYAN} BACKUPKIT USER HOME ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "1) Backup user home"
        echo "2) Restore user home"
        echo "3) Verify last backup user home"
        echo "4) Doctor backups user home"
        echo "5) Garbage old snapshots"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Choice [1-#]: " c

        case "$c" in
            1) remedia backupkit home backup || true ;;
            2) remedia backupkit home restore || true ;;
            3) remedia backupkit home verify || true ;;
            4) remedia backupkit home doctor || true ;;
            5) remedia backupkit home garbage || true ;;
            0)
                return
                ;;
        esac
        
        read -rp "Press Enter..."
    done
}
