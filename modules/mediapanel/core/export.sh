#!/usr/bin/env bash
# modules/mediapanel/core/export.sh

export_youtube() {
    local project
    project="$(require_active_project)" || return 1

    local dir="$PROJECT_DIR/$project/export"

    mapfile -t files < <(
        find "$dir" -type f -iname "*.mp4"
    )

    if (( ${#files[@]} == 0 )); then
        log_warn "No export files found in $dir"
        return 1
    fi

    echo
    echo "Available export files:"
    echo "------------------------------------"

    local i=1
    for f in "${files[@]}"; do
        echo "$i) $(basename "$f")"
        ((i++))
    done

    echo "------------------------------------"
    read -rp "Select file [1-${#files[@]}]: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#files[@]} )); then
        log_error "Invalid selection"
        return 1
    fi

    local file="${files[$((choice-1))]}"

    log_info "File ready for upload:"
    echo "$file"

    echo
    echo "=================================================="
    echo " MANUAL UPLOAD MODE"
    echo "=================================================="
    echo "✔ File is prepared"
    echo "✔ YouTube upload is NOT automated yet"
    echo
    echo "👉 Open manually:"
    echo "   https://studio.youtube.com/upload"
    echo
    echo "👉 Select file above and upload"
    echo "=================================================="

    pause
}

archive_project() {

    local project_name="${1:-}"

    # fallback: active project
    if [[ -z "$project_name" ]]; then
        project_name="$(require_active_project)" || return 0
    fi

    local project_path="$PROJECT_DIR/$project_name"

    if [[ ! -d "$project_path" ]]; then
        log_error "Project directory not found: $project_path"
        return 1
    fi

    local archive_dir="${ARCHIVE_VIDEO_DIR:-$MEDIAPANEL_BACKUPS}"
    mkdir -p "$archive_dir"

    local archive="$archive_dir/${project_name}_archive_$(date +%Y%m%d).tar.gz"

    log_info "Archiving project: $project_name → $archive"

    local size=0
    if command -v du >/dev/null 2>&1; then
        size=$(du -sb "$project_path" 2>/dev/null | cut -f1 || echo 0)
    fi

    if command -v pv >/dev/null 2>&1; then
        tar -cf - -C "$PROJECT_DIR" "$project_name" \
            | pv -s "$size" \
            | gzip > "$archive"
    else
        tar -czf "$archive" -C "$PROJECT_DIR" "$project_name"
    fi

    log_info "Project archived: $project_name"
    log_info "Archive saved: $archive"

    return 0
}

