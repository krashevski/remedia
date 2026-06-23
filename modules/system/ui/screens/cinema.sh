#!/usr/bin/env bash
# modules/system/ui/screens/man.sh

screen_cinema() {
    while true; do
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                  ${COLOR_BOLD}${COLOR_CYAN} DEMO CINEMA ${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        render_header
        echo ""
        echo "Demo module for simulating transactional workflows in a cinema production pipeline"
        echo
        echo "1) Cinema run"
        echo "2) Cinema replay"
        echo "3) Cinem scrub"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Select [1-#]: " c

        case "$c" in
            1) remedia demo cinema run ;;
            2) remedia demo cinema replay ;;
            3) remedia demo cinema scrub ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        read -rp "Press Enter..."
    done
}
