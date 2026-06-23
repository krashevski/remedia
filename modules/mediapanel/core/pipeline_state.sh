#!/usr/bin/env bash
# mediapanel/core/pipeline_state.sh

PIPELINE_STEPS=(
  ingest
  proxy
  audio
  sync
  split
)

pipeline_state_file() {
    local project="$1"
    [[ -n "$project" ]] || return 1
    echo "$PROJECT_DIR/$project/.pipeline_state"
}

pipeline_load() {
    local project="$1"
    local file
    file="$(pipeline_state_file "$project")"

    mkdir -p "$(dirname "$file")"

    if [[ ! -f "$file" ]]; then
        cat > "$file" <<EOF
ingest=pending
proxy=pending
audio=pending
sync=pending
split=pending
status=active
EOF
    fi
}

pipeline_get() {
    local project="$1"
    local key="$2"

    local file
    file="$(pipeline_state_file "$project")"

    [[ -f "$file" ]] || return 0

    awk -F= -v k="$key" '$1==k {print $2}' "$file"
}

pipeline_set() {
    local project="$1"
    local key="$2"
    local value="$3"

    local file
    file="$(pipeline_state_file "$project")"

    grep -q "^$key=" "$file" \
        && sed -i "s|^$key=.*|$key=$value|" "$file" \
        || echo "$key=$value" >> "$file"
}

pipeline_lock_file() {
    echo "$PROJECT_DIR/$1/.pipeline.lock"
}

pipeline_lock() {
    local project="$1"
    local lock="$(pipeline_lock_file "$project")"

    if [[ -f "$lock" ]]; then
        echo "[PIPELINE] already running"
        return 1
    fi

    echo $$ > "$lock"
}

pipeline_unlock() {
    local project="$1"
    rm -f "$(pipeline_lock_file "$project")"
}

run_step() {
    local project="$1"
    local step="$2"

    pipeline_set "$project" "$step" running

    case "$step" in
        proxy) generate_proxy ;;
        audio) audio_cleanup ;;
        sync) auto_sync_audio ;;
        split) batch_scene_split ;;
        ingest) echo "[STEP] ingest external" ;;
        *) echo "[ERROR] unknown step: $step"; return 1 ;;
    esac

    pipeline_set "$project" "$step" done
}

resume_pipeline() {
    local project
    project="$(require_active_project)" || return 1

    pipeline_load "$project"

    for step in proxy audio sync split; do
        local state
        state="$(pipeline_get "$project" "$step" || echo pending)"

        if [[ "$state" != "done" ]]; then
            echo "[RESUME] $step"
            run_step "$project" "$step"
            return 0
        fi
    done

    echo "[OK] complete"
}

full_pipeline() {
    local project
    project="$(require_active_project)" || return 1

    pipeline_load "$project"
    pipeline_lock "$project" || return 1

    require_ingest_done || return 1

    for step in proxy audio sync split; do
        run_step "$project" "$step"
    done

    pipeline_set "$project" status done
    pipeline_unlock "$project"

    echo "[OK] full pipeline done"
}

retry_step() {
    local project="$1"
    local step="$2"

    pipeline_set "$project" "$step" pending

    run_step "$project" "$step"
}

skip_step() {
    local project="$1"
    local step="$2"

    pipeline_set "$project" "$step" skipped
}

pipeline_status() {   
    local project="$1"
    local out=""
    echo -e "${COLOR_BOLD}Pipeline status:${COLOR_RESET}"
    for step in "${PIPELINE_STEPS[@]}"; do
        local state
        state="$(pipeline_get "$project" "$step" || echo missing)"

        case "$state" in
            done)
                out+="${COLOR_GREEN}✔ $step${COLOR_RESET}\n"
                ;;
            pending)
                out+="${COLOR_YELLOW}⟳ $step${COLOR_RESET}\n"
                ;;
            running)
                out+="${COLOR_CYAN}▶ $step (running)${COLOR_RESET}\n"
                ;;
            skipped)
                out+="${COLOR_BLUE}— $step (skipped)${COLOR_RESET}\n"
                ;;
            failed)
                out+="${COLOR_RED}✖ $step (failed)${COLOR_RESET}\n"
                ;;
            *)
                out+="${COLOR_MAGENTA}⚠ $step (unknown)${COLOR_RESET}\n"
                ;;
        esac
    done
    echo -e "${COLOR_CYAN}----------------------------------${COLOR_RESET}" 
    echo -e "$out" 
}

