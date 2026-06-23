#!/usr/bin/env bash
# modules/mediapanel/core/production.sh

# =========================
# REQUIRE ACTIVE PROJECT
# =========================
require_active_project() {
    local p
    p="$(get_active_project)"

    [[ -n "$p" ]] || {
        echo "[ERROR] no active project selected"
        return 1
    }

    echo "$p"
}

require_ingest_done() {
    local project
    project="$(require_active_project)" || return 1

    local state
    state="$(pipeline_get "$project" "ingest" || echo "missing")"

    if [[ "$state" == "done" ]]; then
        return 0
    fi

    if [[ "${PIPELINE_STRICT:-0}" == "0" ]]; then
        echo "[WARN] ingest missing (loose mode allowed)"
        return 0
    fi

    echo "[BLOCKED] ingest required"
    return 1
}

log_error() {
    local project="$1"
    local message="$2"

    log_project "$project" "[ERROR] $message"
}

log_project() {
    local project="$1"
    local message="$2"

    local project_path="$PROJECT_DIR/$project"
    local logfile="$project_path/.log"

    mkdir -p "$project_path"

    printf "[%s] [%s] %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$USER" \
        "$message" >> "$logfile"
}

# =========================
# GENERATE PROXY
# =========================
generate_proxy() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1
    
    echo "[Production] generating proxy for $project"
    
    log_project "$project" "Proxy generation started"

    local project_path="$PROJECT_DIR/$project"
    [[ -d "$project_path" ]] || {
        echo "[ERROR] project not found"
        log_error "$project" "No video files in $src"
        return 1
    }   
    local src="$project_path/media"
    
    local proxy_dir="$(storage_fast)/projects/$project"
    local dst="$proxy_dir/proxy"

    mkdir -p "$dst"

    shopt -s nullglob
    local files=("$src"/*.mp4)
    shopt -u nullglob

    (( ${#files[@]} == 0 )) && {
        echo "[WARN] no video files found"
        return 1
    }

    for f in "${files[@]}"; do
        name=$(basename "$f")
        proxy="$dst/${name%.*}_proxy.mp4"

        ffmpeg -y -i "$f" \
            -vf scale=1280:-2 \
            -c:v libx264 -crf 28 \
            "$proxy"
        log_project "$project" "Processing: $name → $(basename "$proxy")"
    done

    log_project "$project" "Proxy generation completed"
    pipeline_set "$project" "proxy" "done"
    echo
    echo "[OK] proxy generated for $project"
}


# =========================
# AUDIO CLEANUP
# =========================
audio_cleanup() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] audio cleanup for $project"
    log_project "$project" "Audio cleanup started"

    local project_path="$PROJECT_DIR/$project"
    local src="$project_path/media"
    local dst="$project_path/audio"

    mkdir -p "$dst"

    mapfile -d '' files < <(
        find "$src" -type f \( \
            -iname "*.mp4" -o \
            -iname "*.mov" -o \
            -iname "*.mkv" -o \
            -iname "*.wav" -o \
            -iname "*.mp3" -o \
            -iname "*.m4a" \
        \) -print0
    )

    local total=${#files[@]}

    (( total == 0 )) && {
        echo "[WARN] no media files"
        log_error "$project" "No media files for audio cleanup"
        return 1
    }

    local count=1

    for file in "${files[@]}"; do

        local name base output
        name=$(basename "$file")
        base="${name%.*}"
        output="$dst/${base}_clean.wav"

        echo "[$count/$total] $name"

        if [[ -f "$output" ]]; then
            echo "[SKIP] exists"
            ((count++))
            continue
        fi

        ffmpeg -y -i "$file" \
            -vn \
            -af "adeclip,adeclick,acompressor,loudnorm" \
            "$output"

        ((count++))
        log_project "$project" "Cleaning audio: $name"
    done

    log_project "$project" "Audio cleanup completed ($total files)"
    pipeline_set "$project" "audio" "done"  
    echo
    echo "[OK] audio cleaned"
}

# =========================
# AUTO SYNC AUDIO
# =========================
auto_sync_audio() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] syncing audio for $project"
    log_project "$project" "Audio sync started"

    local project_path="$PROJECT_DIR/$project"
    local video_dir="$project_path/media"
    local audio_dir="$project_path/audio"
    local output_dir="$project_path/edit"

    mkdir -p "$output_dir"

    mapfile -d '' videos < <(
        find "$video_dir" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) -print0
    )

    local total=${#videos[@]}

    (( total == 0 )) && {
        echo "[WARN] no videos"
        log_error "$project" "No videos for sync"
        return 1
    }

    local count=1

    for video in "${videos[@]}"; do

        local name base clean_audio output
        name=$(basename "$video")
        base="${name%.*}"

        clean_audio="$audio_dir/${base}_clean.wav"
        output="$output_dir/${base}_sync.mp4"

        echo "[$count/$total] $name"

        if [[ ! -f "$clean_audio" ]]; then
            echo "[SKIP] no cleaned audio"
            log_error "$project" "Missing cleaned audio for $base"
            ((count++))
            continue
        fi

        ffmpeg -y \
            -i "$video" \
            -i "$clean_audio" \
            -map 0:v:0 \
            -map 1:a:0 \
            -c:v copy \
            -c:a aac -b:a 192k \
            "$output"

        ((count++))
        log_project "$project" "Sync: $name"
    done

    log_project "$project" "Audio sync completed"
    pipeline_set "$project" "sync" "done"  
    echo
    echo "[OK] audio synced"
}

# =========================
# BATCH SCENE SPLIT
# =========================
batch_scene_split() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] scene split for $project"
    log_project "$project" "Scene split started"

    local project_path="$PROJECT_DIR/$project"
    local src="$project_path/edit"
    local dst="$project_path/scenes"

    mkdir -p "$dst"

    mapfile -d '' videos < <(
        find "$src" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) -print0
    )

    local total=${#videos[@]}

    (( total == 0 )) && {
        echo "[WARN] no videos to split"
        log_project "$project" "No scene changes detected, fallback frame created"
        return 1
    }

    local count=1

    for video in "${videos[@]}"; do

        local name base outdir
        name=$(basename "$video")
        base="${name%.*}"
        outdir="$dst/$base"

        mkdir -p "$outdir"

        echo "[$count/$total] $name"

        ffmpeg -i "$video" \
            -c copy \
            -f segment \
            -segment_time 10 \
            -reset_timestamps 1 \
            "$outdir/${base}_scene_%03d.mp4"

        ((count++))
        log_project "$project" "Splitting scenes: $name"
    done

   log_project "$project" "Scene split completed"
    pipeline_set "$project" "split" "done"   
    echo
    echo "[OK] scenes created"
}

# =========================
# LAUNCH SHOTCUT
# =========================
launch_shotcut() {

    local project
    project="$(require_active_project)" || return 1

    echo "[Production] launching Shotcut for $project"
    log_project "$project" "Shotcut launched"

    if command -v flatpak &>/dev/null; then
        flatpak run org.shotcut.Shotcut
    else
        shotcut
    fi
    log_project "$project" "Shotcut closed"
}




