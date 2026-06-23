#!/usr/bin/env bash
# modules/demo/modules/cinema/replay.sh

replay() {
    echo "🎬 REMEDIA REPLAY MODE"
    echo ""

    [[ -f "$STATE_FILE" ]] || {
        echo "[EMPTY] no events"
        return 0
    }

    # 🔥 надёжный выбор сессии
    local session
    session=$(awk -F'|' 'NF {last=$1} END {print last}' "$STATE_FILE")

    [[ -z "$session" ]] && {
        echo "[ERROR] no valid session found"
        return 1
    }

    echo "🎞 SESSION: $session"
    echo ""

    while IFS='|' read -r s type data; do
        [[ "$s" != "$session" ]] && continue

        case "$type" in
            STEP)
                echo "🎞️ STEP"
                echo "   └─ $data"
                ;;
            OK)
                echo "🎬 OK"
                echo "   └─ $data"
                ;;
            FAIL)
                echo "❌ FAIL"
                echo "   └─ $data"
                ;;
        esac

        sleep "${REPLAY_SPEED:-0.2}"
    done < "$STATE_FILE"

    echo ""
    echo "✨ END OF REPLAY"
}
