#!/usr/bin/env bash
# modules/system/ui/select.sh

ui_select() {
    local prompt="$1"
    shift
    local items=("$@")

    case "$(ui_backend)" in
        fzf)
            printf "%s\n" "${items[@]}" | fzf --prompt="$prompt > "
            ;;
        dialog)
            local args=()
            local i=1
            for item in "${items[@]}"; do
                args+=("$i" "$item")
                ((i++))
            done
            dialog --menu "$prompt" 15 60 6 "${args[@]}" 3>&1 1>&2 2>&3
            ;;
        *)
            echo "$prompt"
            local i=1
            for item in "${items[@]}"; do
                echo "$i) $item"
                ((i++))
            done
            read -rp "Select: " idx
            echo "${items[$((idx-1))]}"
            ;;
    esac
}
