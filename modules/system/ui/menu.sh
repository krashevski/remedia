#!/usr/bin/env bash
# modules/system/ui/menu.sh

ui_menu() {
    local title="$1"
    shift
    
    echo "== $title =="
    
    ui_select "$title" "$@"
}
