#!/usr/bin/env bash
# modules/system/ui/screens/mediapanel.sh

screen_mediapanel() {
    clear
    render_header
    echo
    echo "[MEDIAPANEL]"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_module "mediapanel" remedia mediapanel status
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Interactive user interface"
    echo
    echo "1) UI"
    echo "2) Help"
    echo
    echo "0) Back"
    echo
    read -rp "Select: " c

    case "$c" in        
        1) remedia mediapanel ui ;;
        2) remedia mediapanel help ;;
        *) return ;;
    esac
}
