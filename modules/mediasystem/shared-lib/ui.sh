#!/bin/bash
# modules/mediasystem/shared-lib/ui.sh

draw_progress() {
    local current=${1:-${CURRENT:-0}}
    local total=${2:-${TOTAL_MODULES:-0}}
    local width=30

    if [ "$total" -eq 0 ]; then
        percent=0
    else
        percent=$((current * 100 / total))
    fi

    filled=$((percent * width / 100))
    empty=$((width - filled))

    bar=$(printf "%${filled}s" | tr ' ' '#')
    space=$(printf "%${empty}s")

    # <-- тут добавили очистку строки
    printf "\r\033[K[%s%s] %d%% (%d/%d)" "$bar" "$space" "$percent" "$current" "$total"

    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

clear_progress_line() {
    printf "\r\033[K"
}
