#!/usr/bin/env bash
# modules/system/ui/backend.sh

ui_backend() {
    if [[ "$UI_MODE" == "auto" ]]; then
        command -v fzf >/dev/null && echo "fzf" && return
        command -v dialog >/dev/null && echo "dialog" && return
        echo "cli"
    else
        echo "$UI_MODE"
    fi
}
