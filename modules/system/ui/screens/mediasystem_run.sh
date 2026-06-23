#!/usr/bin/env bash
# modules/system/ui/screens/mediasystem_run.sh

screen_mediasystem_run() {
    clear
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "                ${COLOR_BOLD}${COLOR_CYAN} MEDIASYSTEM RUN${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    render_header
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_module "mediasystem" remedia mediasystem status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Module of media system setup and GPU optimization tools"
    echo

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/mediasystem"

    # вернуть контроль терминала
    exec < /dev/tty

    # выбор режима
    while true; do
        echo "Select pipeline mode:"
        echo "1) safe"
        echo "2) standard"
        echo "3) full"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Choice [1-#]: " choice

        case "$choice" in
            1) PIPELINE_MODE="safe"; break ;;
            2) PIPELINE_MODE="standard"; break ;;
            3) PIPELINE_MODE="full"; break ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
    done

    export PIPELINE_MODE

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[RUNNING: $PIPELINE_MODE]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    bash "$SCRIPT_DIR/bootstrap_pipeline.sh"

    echo
}
