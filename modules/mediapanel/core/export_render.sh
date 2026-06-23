#!/usr/bin/env bash
# modules/mediapanel/core/export_render.sh

export_render() {
    local project
    project="$(require_active_project)" || return 1

    local src="$PROJECT_DIR/$project/edit"
    local dst="$PROJECT_DIR/$project/export"

    mkdir -p "$dst"

    log_info "=== Export Render started ==="

    mapfile -t videos < <(
        find "$src" -type f -iname "*.mp4"
    )

    if (( ${#videos[@]} == 0 )); then
        log_warn "No edit files found"
        return 1
    fi

    for video in "${videos[@]}"; do
        local name base out

        name=$(basename "$video")
        base="${name%.*}"
        out="$dst/${base}_final.mp4"

        log_info "Rendering: $name → export"

        ffmpeg -y -i "$video" \
            -c:v libx264 -crf 18 -preset slow \
            -c:a aac -b:a 192k \
            -movflags +faststart \
            "$out"
    done

    pipeline_set "$project" "export" "done"
    log_info "=== Export Render completed ==="
}




