#!/usr/bin/env bash
# modules/system/ui/screens/backupkit_users.sh

screen_users() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                 ${COLOR_BOLD}${COLOR_CYAN} BACKUPKIT USERS ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo
        echo "User initialization for the module backupkit"
        echo
        echo "1) List users"
        echo "2) Add user"
        echo "3) Disable user"
        echo "4) Enable user"
        echo "5) Purge user"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Choice [1-#]: " c

        case "$c" in
            1)
                remedia backupkit user list
                ;;
            2)
                read -rp "Enter username: " u
                if [[ -z "$u" ]]; then
                    echo "[ERROR] empty username"
                    return
                fi
                remedia backupkit user add "$u"
                ;;
            3)
                read -rp "Enter username: " u
                if [[ -z "$u" ]]; then
                    echo "[ERROR] empty username"
                    return
                fi
                remedia backupkit user disable "$u"
                ;;
            4)
                read -rp "Enter username: " u
                if [[ -z "$u" ]]; then
                    echo "[ERROR] empty username"
                    return
                fi
                remedia backupkit user enable "$u"
                ;;
            5)
                read -rp "Enter username: " u
                if [[ -z "$u" ]]; then
                    echo "[ERROR] empty username"
                    return
                fi
                remedia backupkit user remove "$u" --purge
                ;;
            0)
                return
                ;;
        esac
        
        read -rp "Press Enter..."
    done
}
