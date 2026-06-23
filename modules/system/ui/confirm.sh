#!/usr/bin/env bash
# modules/system/ui/confirm.sh

ui_confirm() {
    local prompt="$1"

    case "$(ui_backend)" in
        fzf)
            echo "yes
no" | fzf --prompt="$prompt > " | grep -q yes
            ;;
        dialog)
            dialog --yesno "$prompt" 10 50
            ;;
        *)
            read -rp "$prompt [y/N]: " ans
            [[ "$ans" =~ ^[Yy]$ ]]
            ;;
    esac
}
