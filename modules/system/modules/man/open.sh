#!/usr/bin/env bash
# modules/system/modules/man/open.sh

man_open() {
    local page="${1:-}"
    local -a pages=(
        users-home-restore
        nvidia-display-restore
        nvidia-flatpak-nvenc
    )

    if [[ -z "$page" ]]; then
        echo "Select a man page:"

        local i
        for i in "${!pages[@]}"; do
            printf '  %d) %s\n' "$((i + 1))" "${pages[i]}"
        done
        echo "  0) Back"

        local choice
        read -r -p "Choice: " choice || return 0

        if [[ "$choice" == "0" || -z "$choice" ]]; then
            return 0
        fi

        if [[ ! "$choice" =~ ^[1-9][0-9]*$ ]] ||
            (( choice > ${#pages[@]} )); then
            echo "[ERROR] invalid choice"
            return 1
        fi

        page="${pages[$((choice - 1))]}"
    fi

    if ! man -w -- "$page" >/dev/null 2>&1; then
        echo "[ERROR] man page not found: $page"
        return 1
    fi

    echo "[MAN] [OPEN] opening: $page"
    man -- "$page"
    local result=$?
    echo "[MAN] [OPEN] closed"
    return "$result"
}
