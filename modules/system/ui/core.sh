#!/usr/bin/env bash
# modules/system/ui/core.sh

UI_MODE="${REM_SYSTEM_UI:-auto}"   # auto|cli|tui|silent

ui_mode() {
    echo "$UI_MODE"
}

ui_enabled() {
    [[ "$UI_MODE" != "silent" ]]
}



