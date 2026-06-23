#!/usr/bin/env bash
# modules/mediapanel/modules/media_pool.sh

# set -o pipefail
# set +e

INGEST_INTERACTIVE="${INGEST_INTERACTIVE:-0}"

declare -gA MEDIA_INDEX

# =========================
# MEDIA STATES (как в NLE)
# =========================
# REMOTE  - файл найден на устройстве (телефон)
# INGEST  - идет копирование
# LOCAL   - файл скопирован в проект
# READY   - готов к монтажу (опционально, следующий этап)

: "${STATE_DIR:?STATE_DIR not set}"
: "${PROJECT_DIR:?PROJECT_DIR not set}"
: "${JOURNAL:=$STATE_DIR/media_journal.log}"

# =========================
# AUTO DETECT PHONE (GVFS/MTP)
# =========================
detect_phone() {
    local gvfs="/run/user/$UID/gvfs"

    [[ -d "$gvfs" ]] || return 1

    local dev base

    while IFS= read -r dev; do

        for base in \
            "Internal shared storage/DCIM/Camera" \
            "Internal shared storage/DCIM" \
            "Internal shared storage/Movies" \
            "Внутренняя память/DCIM"
        do
            if [[ -d "$dev/$base" ]]; then
                echo "$dev/$base"
                return 0
            fi
        done

    done < <(find "$gvfs" -maxdepth 1 -type d -name "mtp:*" 2>/dev/null)

    return 1
}

ui_log() {
    local msg="${1:-}"
    echo -e "[MEDIA] $msg" >&2
}

ui_banner() {
    echo
    echo -e "${BOLD}${CYAN}====================================================${RESET}"
    echo -e "               ${BOLD}${CYAN}$1${RESET}"
    echo -e "${BOLD}${CYAN}====================================================${RESET}"
    echo
}

prepare_ingest_queue() {
    local phone_dir="$1"

    mapfile -d '' QUEUE < <(
        find "$phone_dir" -type f -iname "*.mp4" -print0
    )

    TOTAL_FILES="${#QUEUE[@]}"

    ui_banner "INGEST QUEUE READY"
    ui_log "Total files: $TOTAL_FILES"
    return 0
}

log_event() {
    local hash="$1"
    local event="$2"
    local payload="$3"

    echo "$(date +%s)|$hash|$event|$payload" >> "$JOURNAL"
}

ensure_media_db() {
    mkdir -p "$STATE_DIR"
    mkdir -p "$RAW_DIR"
    [[ -f "$MEDIA_DB" ]] || touch "$MEDIA_DB"
    touch "$JOURNAL"
}

# IDENTITY LAYER (как в DaVinci)
hash_file() {
    sha1sum "$1" 2>/dev/null | awk '{print $1}'
}

rebuild_state() {

    declare -gA STATE_HASH=()
    declare -gA STATE_FILE=()
    declare -gA STATE_NAME=()
    declare -gA STATE_PROJECT=()
    declare -gA STATE_RAW=()

    while IFS='|' read -r ts hash event rest || [[ -n "$ts" ]]; do

        # защита
        [[ -z "$hash" ]] && continue

        case "$event" in

            FOUND)
                # rest = path|project
                payload="${rest%%|*}"
                project="${rest#*|}"

                STATE_HASH["$hash"]="REMOTE"
                STATE_PROJECT["$hash"]="$project"
                STATE_NAME["$hash"]="$(basename "$payload")"
                ;;

            RAW_DONE)
                STATE_HASH["$hash"]="RAW"
                STATE_RAW["$hash"]="$rest"
                ;;

            LOCAL_DONE)
                STATE_HASH["$hash"]="LOCAL"
                STATE_FILE["$hash"]="$rest"
                ;;

            FAILED)
                STATE_HASH["$hash"]="FAILED"
                ;;

        esac

    done < "$JOURNAL"

    echo "[DEBUG] total hashes: ${#STATE_HASH[@]}"
}

media_index_load() {
    ensure_media_db

    while IFS=$'\t' read -r hash _; do
        MEDIA_INDEX["$hash"]=1
    done < "$MEDIA_DB"
}

media_register() {
    local file="$1"
    local project="$2"

    local hash
    hash="$(hash_file "$file")"

    [[ -z "$hash" ]] && return 1

    # 🔥 вместо grep
    [[ -n "${MEDIA_INDEX[$hash]}" ]] && return 0

    echo -e "$hash\t$(basename "$file")\t$file\t$project\tREMOTE\t" >> "$MEDIA_DB"

    MEDIA_INDEX["$hash"]=1

    echo "[MEDIA] registered: $(basename "$file")" >&2
}

media_import_phone() {
    local phone_dir="$1"
    local project="$2"

    ensure_media_db
    media_index_load

    mapfile -d '' files < <(
        find "$phone_dir" -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0
    )

    echo "[MEDIA] scanning ${#files[@]} files" >&2

    for f in "${files[@]}"; do
        media_register "$f" "$project" || true
    done

    echo "[MEDIA] import done" >&2
}

copy_with_retry() {
    local src="$1"
    local dst="$2"
    local tmp="${dst}.tmp.$$"

    for i in 1 2 3; do
        ui_log "copy attempt $i → $(basename "$src")"

        if cp "$src" "$tmp" >/dev/null 2>&1 && mv "$tmp" "$dst"; then
            ui_log "copied ✓ $(basename "$dst")"
            return 0
        fi

        rm -f "$tmp"
        sleep 1
    done

    ui_log "copy failed ✗ $(basename "$src")"
    return 1
}

media_materialize() {

    local hash="$1"

    rebuild_state

    case "${STATE_HASH[$hash]}" in

        LOCAL|RAW)
            echo "${STATE_FILE[$hash]}"
            return 0
            ;;

        REMOTE)
            echo "[MEDIA] not ingested yet"
            return 1
            ;;

        FAILED)
            echo "[MEDIA] failed state"
            return 1
            ;;
    esac
}

media_list() {
    rebuild_state

    echo "=== MEDIA POOL v2 ==="

    for h in "${!STATE_HASH[@]}"; do

        printf "%-6s %-20s %-10s %s\n" \
            "${STATE_HASH[$h]}" \
            "${STATE_NAME[$h]}" \
            "$h" \
            "${STATE_FILE[$h]}"

    done | sort
}

cleanup_raw() {
    local raw_file="$1"

    if [[ -f "$raw_file" ]]; then
        rm -f "$raw_file"
        ui_log "RAW cleaned 🧹 $(basename "$raw_file")"
    fi
}

cleanup_raw_batch() {
    ui_log "Cleaning RAW cache..."
    
    [[ -d "$RAW_DIR" ]] || {
        ui_log "RAW dir missing, skip cleanup"
        return 0
    }

    find "$RAW_DIR" -type f -mtime +0 -print -delete | while read -r f; do
        ui_log "deleted $(basename "$f")"
    done
}

ingest_to_raw() {
    local src="$1"
    local name
    name="$(basename "$src")"
    
    echo "[RAW] ingest: $name" >&2

    local dst="$RAW_DIR/$name"

    # уже есть
    [[ -f "$dst" ]] && {
        echo "$dst"
        return 0
    }

    # retry копирование с телефона
    for i in 1 2 3; do
        if copy_with_retry "$src" "$dst"; then
            echo "$dst"
            ui_log "RAW ingest: $(basename "$f")"
            return 0
        fi
        sleep 1
    done
        
    return 1
}

ingest_from_phone_v3() {

    local start_ts end_ts

    start_ts=$(date +%s%3N)

    local phone_dir project
    local ok=0 fail=0 skip=0 total=0 error=""

    phone_dir="$(detect_phone 2>/dev/null || true)"
    project="$(get_active_project 2>/dev/null || true)"

    # ========= SAFE GUARD =========
    if [[ -z "$phone_dir" || -z "$project" ]]; then
        echo '{"ok":0,"fail":0,"skip":0,"total":0,"error":"no_device_or_project","runtime_ms":0}'
        return 0
    fi

    mapfile -d '' QUEUE < <(
        find "$phone_dir" -type f \( -iname "*.mp4" -o -iname "*.mov" \) -print0
    )

    total="${#QUEUE[@]}"
    local idx=0
    ((idx++))
    
    # ========= LOOP =========
    for f in "${QUEUE[@]}"; do
        local name raw dst hash

        name="$(basename "$f")"
        raw="$RAW_DIR/$name"
        dst="$PROJECT_DIR/$project/media/$name"

        # ========= PLAN =========
        if [[ "$name" == .trashed-* ]]; then
            ((skip++))
            continue
        fi

        if [[ -f "$dst" ]]; then
            ((skip++))
            continue
        fi

        # ========= RAW INGEST =========
        if ! copy_with_retry "$f" "$raw"; then
            ((fail++))
            continue
        fi

        # ========= VERIFY RAW =========
        hash="$(sha1sum "$raw" 2>/dev/null | awk '{print $1}')"

        if [[ -z "$hash" ]]; then
            ((fail++))
            continue
        fi

        # ========= MATERIALIZE =========
        if ! copy_with_retry "$raw" "$dst"; then
            ((fail++))
            continue
        fi

        # ========= VERIFY v2 =========
        if ! cmp -s "$raw" "$dst"; then
            rm -f "$dst"
            ((fail++))
            continue
        fi

        # ========= REGISTER =========
        log_event "$hash" "FOUND" "$f|$project"
        log_event "$hash" "RAW_DONE" "$raw"
        log_event "$hash" "LOCAL_DONE" "$dst"

        cleanup_raw "$raw"

        ((ok++))
        ((idx++))
        ui_log "[$idx/$total] $(basename "$f")"
    done

    end_ts=$(date +%s%3N)

    local runtime=$((end_ts - start_ts))

    # ========= STRICT OUTPUT =========
    printf '{"ok":%d,"fail":%d,"skip":%d,"total":%d,"error":"","runtime_ms":%d}\n' \
        "$ok" "$fail" "$skip" "$total" "$runtime"
}

open_media() {
    local hash="$1"

    local file
    file="$(media_materialize "$hash")"

    echo "$file"
}


