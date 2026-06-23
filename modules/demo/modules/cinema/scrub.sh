#!/usr/bin/env bash
# modules/demo/modules/cinema/scrub.sh

scrub() {
    [[ -f "$STATE_FILE" ]] || {
        echo "[EMPTY] no events"
        return 0
    }

    # 🎯 выбрать сессию
    local session="${1:-}"
    if [[ -z "$session" ]]; then
        session=$(tail -n1 "$STATE_FILE" | cut -d'|' -f1)
    fi

    # 🎞 собрать только события этой сессии
    mapfile -t EVENTS < <(grep "^$session|" "$STATE_FILE")

    local pos=0
    local max=${#EVENTS[@]}

    [[ $max -eq 0 ]] && {
        echo "[EMPTY] no events for session $session"
        return 0
    }

    while true; do
        clear
        echo "🎬 SCRUB MODE v2"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎞 SESSION: $session"
        echo "n=next p=prev q=quit"
    
        local line="${EVENTS[$pos]}"
        IFS='|' read -r _ type data <<< "$line"

        echo "🎬 FRAME $((pos+1))/$max"
        cinema_render_event "$type" "$data"

        read -n1 key

        case "$key" in
            n) (( pos < max-1 )) && ((pos++)) ;;
            p) (( pos > 0 )) && ((pos--)) ;;
            q) 
               echo "[QUIT]"
               break 
               ;;
        esac
    done
}
