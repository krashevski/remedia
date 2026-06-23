#!/usr/bin/env bash
# modules/system/modules/man/open.sh

man_open() {
    echo "Remedia System Man module"
    echo
    echo "[MAN] [OPEN] opening..."
    
    local page="${1:-users-home-restore}"

    if ! man -w "$page" >/dev/null 2>&1; then
        echo "[ERROR] man page not found: $page"
        return 1
    fi

    # интерактивный режим
    man "$page"
    echo "[MAN] [OPEN] closed"
}
