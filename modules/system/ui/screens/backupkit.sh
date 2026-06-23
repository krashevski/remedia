#!/usr/bin/env bash
# modules/system/ui/screens/backupkit.sh

screen_backupkit() {
    clear
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "                   ${COLOR_BOLD}${COLOR_CYAN} BACKUPKIT ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    render_header
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_module "backupkit" remedia backupkit status || true
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Module of backup and recovery tools"
    echo
    echo "1) Init"
    echo "2) Users"
    echo "3) User home"
    echo "4) Firefox"
    echo
    echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
    echo
    read -rp "Select: " c

    case "$c" in
        1) remedia backupkit init ;;
        2) screen_users ;;
        3) screen_usershome ;;
        4) screen_firefox ;;
        *) return ;;
    esac
}
