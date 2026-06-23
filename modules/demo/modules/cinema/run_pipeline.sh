#!/usr/bin/env bash
# modules/demo/modules/cinema/run_pipeline.sh

set -e

UNDO_STACK=()
EVENTS=()

EVENT_LOG+=("CREATE_DIR:/tmp/demo_tx")

FRAME=0

CINEMA_MODE="${CINEMA_MODE:-demo}"

SESSION_ID="${SESSION_ID:-$(date +%s)}"

frame() {
    FRAME=$((FRAME+1))
    printf "\n🎬 [FRAME %02d]\n" "$FRAME"
}

cinema_prepare_log() {
    case "$CINEMA_MODE" in
        demo)
            : > "$STATE_FILE"
            ;;
        history)
            # ничего не делаем — append-only
            ;;
        *)
            echo "[ERROR] unknown CINEMA_MODE=$CINEMA_MODE"
            exit 1
            ;;
    esac
}

cinema_sleep() {
    sleep "${CINEMA_SPEED:-0.2}"
}


event_emit() {
    local type="$1"
    local data="$2"

    # 🎯 добавляем session
    local line="$SESSION_ID|$type|$data"

    echo "$line" >> "$STATE_FILE"

    echo "🎬 $type"
    echo "   └─ $data"
}

render_rewind() {
    echo ""
    echo "⏪ REWIND STARTED"
}

cinema_render_event() {
    local type="$1"
    local data="$2"

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
}

run_step() {
    local step_file="$1"

    source "$step_file"

    event_emit "STEP" "$step_file"

    local output
    output=$(do_step)
    local status=$?

    if [[ $status -ne 0 ]]; then
        event_emit "FAIL" "$step_file"
        return 1
    fi

    event_emit "OK" "$output"

    UNDO_STACK+=("$step_file")
}

cinema_rewind() {
    echo ""
    echo "⏪ REWIND START"
    echo ""

    sleep 0.5

    for ((i=${#UNDO_STACK[@]}-1; i>=0; i--)); do
        step="${UNDO_STACK[$i]}"

        frame
        echo "🎞️ REWIND FRAME"
        echo "   └─ $step"
        echo "   └─ undo_step"

        cinema_sleep
        source "$step"
        undo_step
    done

    echo ""
    echo "✨ SYSTEM RESTORED"
}

rollback() {
    echo ""
    echo "⏪ REWIND STARTED"
    echo ""

    for ((i=${#UNDO_STACK[@]}-1; i>=0; i--)); do
        step_file="${UNDO_STACK[$i]}"
        source "$step_file"

        echo "🎬 REWIND STEP: $step_file " 
        echo "   ↳ executing: undo_step"
        undo_step
    done
}

main_cinema() {
    cinema_prepare_log

    echo "🎬 CINEMA ENGINE v3"
    echo "🎛 MODE: $CINEMA_MODE"
    echo ""

    for step in "${STEPS[@]}"; do
        run_step "$step" || {
            cinema_rewind
            exit 1
        }
    done

    echo ""
    echo "🎞️ END OF FILM"
}

# main "$@"
