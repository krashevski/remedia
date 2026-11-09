#!/usr/bin/env bash
# modules/mediapanel/core/export.sh

# =========================
# CREATE YOUTUBE METADATA
# =========================
# =========================
# WRITE YOUTUBE METADATA
# =========================
write_youtube_metadata() {

    local media_file="$1"
    local content_type="$2"
    local title="$3"
    local description="$4"
    local tags="$5"
    local visibility="$6"

    local metadata_file="${media_file%.*}.youtube.json"

    command -v python3 >/dev/null 2>&1 || {
        log_error \
            "$(t MP_EXPORT_PYTHON3_IS_REQUIRED_TO_CREATE_JSON_METADATA)"
        return 1
    }

    if ! python3 - \
        "$metadata_file" \
        "$(basename "$media_file")" \
        "$title" \
        "$description" \
        "$tags" \
        "$visibility" \
        "$content_type" <<'PY'
import json
import sys
from datetime import datetime, timezone

(
    metadata_file,
    media_file,
    title,
    description,
    tags_raw,
    visibility,
    content_type,
) = sys.argv[1:]

tags = [
    tag.strip()
    for tag in tags_raw.split(",")
    if tag.strip()
]

metadata = {
    "version": 1,
    "platform": "youtube",
    "backend": "pending",
    "media_file": media_file,
    "title": title,
    "description": description,
    "tags": tags,
    "visibility": visibility,
    "content_type": content_type,
    "status": "prepared",
    "created_at": datetime.now(
        timezone.utc
    ).isoformat(timespec="seconds"),
}

with open(
    metadata_file,
    "w",
    encoding="utf-8",
) as stream:
    json.dump(
        metadata,
        stream,
        ensure_ascii=False,
        indent=2,
    )
    stream.write("\n")
PY
    then
        log_error \
            "$(t MP_EXPORT_FAILED_TO_CREATE_METADATA "$metadata_file")"
        return 1
    fi

    log_info "$(t MP_EXPORT_METADATA_SAVED "$metadata_file")"

    return 0
}

# =========================
# UPDATE DELIVERY STATUS
# =========================
update_delivery_status() {

    local metadata_file="$1"
    local backend="$2"
    local status="$3"

    [[ -f "$metadata_file" ]] || {
        log_error \
            "$(t MP_EXPORT_METADATA_FILE_NOT_FOUND "$metadata_file")"
        return 1
    }

    python3 - \
        "$metadata_file" \
        "$backend" \
        "$status" <<'PY'
import json
import sys
from datetime import datetime, timezone

metadata_file, backend, status = sys.argv[1:]

with open(
    metadata_file,
    "r",
    encoding="utf-8",
) as stream:
    metadata = json.load(stream)

metadata["backend"] = backend
metadata["status"] = status
metadata["updated_at"] = datetime.now(
    timezone.utc
).isoformat(timespec="seconds")

with open(
    metadata_file,
    "w",
    encoding="utf-8",
) as stream:
    json.dump(
        metadata,
        stream,
        ensure_ascii=False,
        indent=2,
    )
    stream.write("\n")
PY
}

# =========================
# MANUAL DELIVERY
# =========================
delivery_manual() {

    local file
    local metadata_file

    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==================================================${COLOR_RESET}"
    echo -e "$(t MP_EXPORT_MANUAL_UPLOAD_MODE "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==================================================${COLOR_RESET}"

    for file in "$@"; do
        metadata_file="${file%.*}.youtube.json"

        if [[ ! -f "$metadata_file" ]]; then
            log_error \
                "$(t MP_EXPORT_METADATA_NOT_FOUND "$metadata_file")"
            continue
        fi

        update_delivery_status \
            "$metadata_file" \
            "manual" \
            "ready_for_upload" || continue

        echo
        echo "$(t MP_EXPORT_MEDIA)"
        echo "   $file"
        echo "$(t MP_EXPORT_METADATA)"
        echo "   $metadata_file"
    done

    echo
    echo "$(t MP_EXPORT_OPEN)"
    echo "   https://studio.youtube.com/upload"
    echo
    echo "=================================================="

    return 0
}

# =========================
# ADD TO DELIVERY QUEUE
# =========================
delivery_enqueue() {

    local project="$1"
    shift

    local state_root="${STATE_DIR:-${HOME}/.remedia}"
    local queue_dir="$state_root/delivery/queue"

    mkdir -p "$queue_dir" || {
        log_error "$(t MP_EXPORT_FAILED_TO_CREATE_QUEUE "$queue_dir")"
        return 1
    }

    local job_id
    job_id="$(date -u '+%Y%m%dT%H%M%SZ')_$$"

    local job_file="$queue_dir/${job_id}.json"

    if ! python3 - \
        "$job_file" \
        "$job_id" \
        "$project" \
        "$@" <<'PY'
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

job_file = Path(sys.argv[1])
job_id = sys.argv[2]
project = sys.argv[3]
media_files = sys.argv[4:]

items = []
metadata_updates = []

# ----------------------------------------
# PREFLIGHT: validate all selected files
# ----------------------------------------

for media_file in media_files:
    media_path = Path(media_file)
    metadata_file = media_path.with_suffix(".youtube.json")

    if not media_path.is_file():
        raise SystemExit(f"Media not found: {media_path}")

    if not metadata_file.is_file():
        raise SystemExit(f"Metadata not found: {metadata_file}")

    with metadata_file.open(encoding="utf-8") as stream:
        metadata = json.load(stream)

    if not isinstance(metadata, dict):
        raise SystemExit(f"Invalid metadata: {metadata_file}")

    status = metadata.get("status")
    video_id = metadata.get("video_id")

    item = {
        "media_file": str(media_path),
        "metadata_file": str(metadata_file),
    }

    # Already uploaded: preserve publication result.
    if status == "uploaded" and video_id:
        item.update({
            "status": "uploaded",
            "video_id": video_id,
            "youtube_url": metadata.get("youtube_url")
                or f"https://youtu.be/{video_id}",
        })

        if metadata.get("uploaded_at"):
            item["uploaded_at"] = metadata["uploaded_at"]

        print(f"Already uploaded: {media_path.name}")
        print(f"  YouTube ID: {video_id}")

    # Inconsistent or uncertain states: do not enqueue.
    elif (
        video_id
        or status in ("uploaded", "uploading", "needs_review", "failed")
    ):
        raise SystemExit(
            f"Metadata requires review: {metadata_file}\n"
            f"  status={status}, video_id={video_id}"
        )

   # New publication or previously prepared manual delivery.
    elif status in ("prepared", "queued", "ready_for_upload"):
        item["status"] = "queued"

        updated = dict(metadata)
        updated["backend"] = "auto"
        updated["status"] = "queued"
        updated["updated_at"] = datetime.now(
            timezone.utc
        ).isoformat(timespec="seconds")

        metadata_updates.append((metadata_file, updated))

    else:
        raise SystemExit(
            f"Unsupported metadata status: {status}"
        )

    items.append(item)

# ----------------------------------------
# SKIP ALREADY COMPLETED DELIVERY
# ----------------------------------------

if items and all(item["status"] == "uploaded" for item in items):
    print()
    print("[OK] All selected videos are already uploaded.")
    print("[INFO] No new delivery job created.")

    for item in items:
        print()
        print(f"  {Path(item['media_file']).name}")
        print(f"  {item['youtube_url']}")

    raise SystemExit(0)

# ----------------------------------------
# CREATE JOB
# ----------------------------------------

job = {
    "version": 1,
    "job_id": job_id,
    "action": "youtube_upload",
    "backend": "auto",
    "project": project,
    "status": "queued",
    "created_at": datetime.now(
        timezone.utc
    ).isoformat(timespec="seconds"),
    "items": items,
}

def atomic_write(path, data):
    fd, temp_name = tempfile.mkstemp(
        prefix=".remedia-",
        suffix=".tmp",
        dir=str(path.parent),
    )

    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(
                data,
                stream,
                ensure_ascii=False,
                indent=2,
            )
            stream.write("\n")

        os.replace(temp_name, path)

    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)

# Write metadata for new publications only.
for path, data in metadata_updates:
    atomic_write(path, data)

# Publish queue job only after metadata writes succeed.
atomic_write(job_file, job)

print(f"Delivery job queued: {job_file}")
PY
    then
        log_error "$(t MP_EXPORT_FAILED_TO_CREATE_DELIVERY_JOB)"
        return 1
    fi

    return 0
}

# =========================
# ARCHIVE DELIVERABLES
# =========================
delivery_archive() {

    local project="$1"
    shift

    local project_path="$PROJECT_DIR/$project"

    local archive_root=""
    archive_root="${ARCHIVE_VIDEO_DIR:-${MEDIAPANEL_BACKUPS:-}}"

    if [[ -z "$archive_root" ]]; then
        log_error \
            "$(t MP_EXPORT_DELIVERY_ARCHIVE_DIRECTORY_IS_NOT_CONFIGURED)"
        return 1
    fi

    local delivery_archive_dir="$archive_root/delivery"

    mkdir -p "$delivery_archive_dir" || {
        log_error \
            "$(t MP_EXPORT_FAILED_TO_CREATE_ARCHIVE_DIRECTORY "$delivery_archive_dir")"
        return 1
    }

    local timestamp
    timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"

    local archive
    archive="$delivery_archive_dir/${project}_delivery_${timestamp}.tar.gz"

    local -a archive_items=()
    local file
    local metadata_file
    local relative_file
    local relative_metadata

    for file in "$@"; do
        metadata_file="${file%.*}.youtube.json"

        if [[ ! -f "$file" ]]; then
            log_error "$(t MP_EXPORT_MEDIA_NOT_FOUND "$file")"
            return 1
        fi

        if [[ ! -f "$metadata_file" ]]; then
            log_error \
                "$(t MP_EXPORT_METADATA_NOT_FOUND "$metadata_file")"
            return 1
        fi

        case "$file" in
            "$project_path"/*)
                ;;
            *)
                log_error \
                    "$(t MP_EXPORT_FILE_IS_OUTSIDE_PROJECT "$file")"
                return 1
                ;;
        esac

        relative_file="${file#"$project_path"/}"
        relative_metadata="${metadata_file#"$project_path"/}"

        archive_items+=(
            "$relative_file"
            "$relative_metadata"
        )
    done

    log_info "$(t MP_EXPORT_CREATING_DELIVERY_ARCHIVE)"
    echo "$archive"

    if ! tar -czf "$archive" \
        -C "$project_path" \
        "${archive_items[@]}"; then

        log_error "$(t MP_EXPORT_FAILED_TO_CREATE_DELIVERY_ARCHIVE)"
        return 1
    fi

    for file in "$@"; do
        metadata_file="${file%.*}.youtube.json"

        if ! update_delivery_status \
            "$metadata_file" \
            "archive" \
            "archived"; then

            log_warn \
                "$(t MP_EXPORT_ARCHIVE_CREATED_BUT_METADATA_STATUS_UPDATE_FAILED)"
            echo "$metadata_file"
        fi
    done

    log_info "$(t MP_EXPORT_DELIVERY_ARCHIVE_SAVED "$archive")"

    echo
    echo "$(t MP_EXPORT_ARCHIVED_FILES)"

    for file in "$@"; do
        echo "   $(basename "$file")"
    done

    echo
    echo "$(t MP_EXPORT_ARCHIVE)"
    echo "   $archive"

    return 0
}

# =========================
# DELIVERY ROUTING
# =========================
delivery_route() {

    local project="$1"
    shift

    local -a files=("$@")

   # Direct routing from the MediaPanel Export menu.
    case "${DELIVERY_ROUTE_MODE:-interactive}" in
        manual)
            delivery_manual "${files[@]}"
            return $?
            ;;
        queue)
            delivery_enqueue "$project" "${files[@]}"
            return $?
            ;;
        interactive)
            ;;
        *)
            log_error "$(t MP_EXPORT_UNKNOWN_DELIVERY_MODE "$DELIVERY_ROUTE_MODE")"
            return 1
            ;;
    esac

    local file
    local metadata_file

    # Stage 1: validate media and metadata.
    for file in "${files[@]}"; do
        metadata_file="${file%.*}.youtube.json"

        [[ -f "$file" ]] || {
            log_error "$(t MP_EXPORT_MEDIA_NOT_FOUND "$file")"
            return 1
        }

        [[ -f "$metadata_file" ]] || {
            log_error \
                "$(t MP_EXPORT_METADATA_NOT_FOUND "$metadata_file")"
            return 1
        }
    done

    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==================================================${COLOR_RESET}"
    echo -e "$(t MP_EXPORT_DELIVERY_ROUTING "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==================================================${COLOR_RESET}"
    echo "$(t MP_UI_1_MANUAL_YOUTUBE_UPLOAD)"
    echo "$(t MP_EXPORT_2_ADD_TO_DELIVERY_QUEUE)"
    echo "$(t MP_EXPORT_3_ARCHIVE_DELIVERABLES)"
    echo
    echo "$(t MP_EXPORT_0_CANCEL "${COLOR_YELLOW}" "${COLOR_RESET}")"
    echo "=================================================="

    local route=""
    read -rp "$(t MP_EXPORT_SELECT_DELIVERY_ROUTE)" route

    case "$route" in
        1)
            delivery_manual \
                "${files[@]}"
            ;;
        2)
            delivery_enqueue \
                "$project" \
                "${files[@]}"
            ;;
        3)
            delivery_archive \
                "$project" \
                "${files[@]}"
            ;;
        0)
            log_info "$(t MP_EXPORT_DELIVERY_CANCELLED)"
            return 0
            ;;
        *)
            log_error "$(t MP_EXPORT_INVALID_DELIVERY_ROUTE)"
            return 1
            ;;
    esac
}

# =========================
# EXPORT TO YOUTUBE
# =========================
export_youtube() {

    local project
    project="$(require_active_project)" || return 1

    local project_path="$PROJECT_DIR/$project"
    local video_dir="$project_path/video"
    local short_dir="$project_path/short"

    local -a files=()
    local -a selected_files=()

    mapfile -d '' -t files < <(
        {
            if [[ -d "$video_dir" ]]; then
                find "$video_dir" \
                    -maxdepth 1 \
                    -type f \
                    -iname "*.mp4" \
                    -print0
             fi

            if [[ -d "$short_dir" ]]; then
                find "$short_dir" \
                    -maxdepth 1 \
                    -type f \
                    -iname "*.mp4" \
                    -print0
            fi
        } | sort -z
    )

    if (( ${#files[@]} == 0 )); then
        log_warn \
             "$(t MP_EXPORT_NO_PUBLICATION_READY_MP4_FILES_FOUND_IN_VIDEO_OR_SHORT)"
        return 1
    fi

    echo
    echo "$(t MP_EXPORT_AVAILABLE_PUBLICATION_FILES)"
    echo "------------------------------------------------"

    local i=1
    local file
    local label

    for file in "${files[@]}"; do
        case "$file" in
            "$video_dir"/*)
                label="$(t MP_KIND_VIDEO)"
                ;;
            "$short_dir"/*)
                label="$(t MP_KIND_SHORT)"
                ;;
            *)
                label="$(t MP_KIND_UNKNOWN)"
                ;;
        esac

        printf '%2d) [%-5s] %s\n' \
            "$i" \
            "$label" \
            "$(basename "$file")"

        ((i++))
    done

    echo "------------------------------------------------"
    echo "$(t MP_EXPORT_SELECT_ONE_OR_SEVERAL_FILES)"
    echo "$(t MP_EXPORT_EXAMPLES_1_1_2_ALL)"
    echo

    local selection=""
    if ! IFS= read -r -p "$(t MP_EXPORT_SELECTION)" selection; then
        log_info "$(t MP_EXPORT_SELECTION_CANCELLED)"
        return 0
    fi

    selection="${selection//,/ }"

    if [[ -z "${selection//[[:space:]]/}" ]]; then
        log_info "$(t MP_EXPORT_SELECTION_CANCELLED)"
        return 0
    fi

    selection="${selection//,/ }"

    if [[ "$selection" == "all" ||
          "$selection" == "a" ]]; then

        selected_files=("${files[@]}")
    else
        local choice
        declare -A selected_numbers=()

        for choice in $selection; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
               (( choice < 1 ||
                  choice > ${#files[@]} )); then

                log_error \
                    "$(t MP_EXPORT_INVALID_SELECTION "$choice")"
                return 1
            fi

            # Prevent duplicate selections.
            if [[ -z "${selected_numbers[$choice]:-}" ]]; then
                selected_files+=(
                    "${files[$((choice - 1))]}"
                )
                selected_numbers["$choice"]=1
            fi
        done
    fi

    if (( ${#selected_files[@]} == 0 )); then
        log_error "$(t MP_EXPORT_NO_FILES_SELECTED)"
        return 1
    fi

    echo
    echo "$(t MP_EXPORT_SELECTED_FILES)"
    echo "------------------------------------------------"

    for file in "${selected_files[@]}"; do
        echo "• $(basename "$file")"
    done

    echo "------------------------------------------------"

    # Check existing metadata.
    local existing_metadata=0
    local missing_metadata=0
    local metadata_file
    local reuse_metadata=""

    for file in "${selected_files[@]}"; do
        metadata_file="${file%.*}.youtube.json"

        if [[ -f "$metadata_file" ]]; then
            ((existing_metadata += 1))
        else
            ((missing_metadata += 1))
        fi
    done

    # All selected files already have metadata.
    if (( missing_metadata == 0 )); then
        echo
        echo "$(t MP_EXPORT_METADATA_JSON_ALREADY_EXISTS_FOR_ALL_SELECTED_FILES)"
        echo

        read -rp \
            "$(t MP_EXPORT_USE_EXISTING_METADATA_WITHOUT_CHANGES_Y_N)" \
            reuse_metadata

        reuse_metadata="${reuse_metadata:-Y}"

        if [[ "$reuse_metadata" =~ ^[YyДд]$ ]]; then
            log_info "$(t MP_EXPORT_USING_EXISTING_METADATA)"

            delivery_route \
                "$project" \
                "${selected_files[@]}"

            local result=$?

            pause
            return "$result"
        fi

        log_info "$(t MP_EXPORT_EXISTING_METADATA_WILL_BE_RECREATED)"
    fi

    local overwrite_existing="Y"

    if (( existing_metadata > 0 &&
          missing_metadata > 0 )); then

        echo
        echo "$(t MP_EXPORT_EXISTING_METADATA "$existing_metadata")"
        echo "$(t MP_EXPORT_MISSING_METADATA "$missing_metadata")"
        echo

        read -rp \
            "$(t MP_EXPORT_RECREATE_EXISTING_METADATA_TOO_Y_N)" \
            overwrite_existing

        overwrite_existing="${overwrite_existing:-N}"
    fi

    # Shared metadata.
    local default_title="$project"
    local title=""
    local description=""
    local tags=""
    local visibility="private"
    local line=""

    echo
    echo "$(t MP_EXPORT_SHARED_YOUTUBE_METADATA)"
    echo "------------------------------------------------"

    read -rp "$(t MP_EXPORT_TITLE "$default_title")" title
    title="${title:-$default_title}"

    echo
    echo "$(t MP_EXPORT_DESCRIPTION)"
    echo "$(t MP_EXPORT_ENTER_ONE_LINE_AT_A_TIME)"
    echo "$(t MP_EXPORT_FINISH_WITH_A_SINGLE_DOT)"
    echo "------------------------------------------------"

    while true; do
        read -rp "> " line || {
            echo
            log_error "$(t MP_EXPORT_DESCRIPTION_INPUT_INTERRUPTED)"
            return 1
        }

        [[ "$line" == "." ]] && break

        if [[ -n "$description" ]]; then
            description+=$'\n'
        fi

        description+="$line"
    done

    read -rp \
        "$(t MP_EXPORT_TAGS_COMMA_SEPARATED)" \
        tags

    while true; do
        read -rp \
            "$(t MP_EXPORT_VISIBILITY_PRIVATE_UNLISTED_PUBLIC_PRIVATE)" \
            visibility

        visibility="${visibility:-private}"

        case "$visibility" in
            private|unlisted|public)
                break
                ;;
            *)
                log_warn \
                    "$(t MP_EXPORT_ALLOWED_VALUES_PRIVATE_UNLISTED_PUBLIC)"
                ;;
        esac
    done

    echo
    echo "$(t MP_EXPORT_CREATING_YOUTUBE_METADATA)"
    echo "------------------------------------------------"

    local content_type
    local created=0
    local failed=0

    for file in "${selected_files[@]}"; do
        metadata_file="${file%.*}.youtube.json"

        # Keep existing JSON unless overwrite was requested.
        if [[ -f "$metadata_file" &&
              ! "$overwrite_existing" =~ ^[YyДд]$ ]]; then

            log_info \
                "$(t MP_EXPORT_USING_EXISTING_METADATA_2 "$metadata_file")"

            continue
        fi

        case "$file" in
            "$video_dir"/*)
                content_type="video"
                ;;
            "$short_dir"/*)
                content_type="short"
                ;;
            *)
                log_error "$(t MP_EXPORT_UNKNOWN_PUBLICATION_TYPE "$file")"
                ((failed += 1))
                continue
                ;;
        esac

        if write_youtube_metadata \
            "$file" \
            "$content_type" \
            "$title" \
            "$description" \
            "$tags" \
            "$visibility"; then

            ((created += 1))
        else
            ((failed += 1))
        fi
    done

    if (( failed > 0 )); then
        log_error \
            "$(t MP_EXPORT_DELIVERY_ROUTING_CANCELLED_METADATA_ERRORS)"
        pause
        return 1
    fi

    delivery_route \
        "$project" \
        "${selected_files[@]}"

    local result=$?

    pause
    return "$result"
}

restore_compact_project_menu() {
    local archive_dir="${ARCHIVE_VIDEO_DIR:-${MEDIAPANEL_BACKUPS:-}}"
    local worker="${MODULE_DIR}/core/restore_compact_project.py"

    if [[ ! -f "$worker" ]]; then
        log_error "$(t MP_EXPORT_RESTORE_MODULE_NOT_FOUND "$worker")"
        return 1
    fi

    if [[ ! -d "$archive_dir" ]]; then
        log_error "$(t MP_EXPORT_ARCHIVE_DIRECTORY_NOT_FOUND "$archive_dir")"
        return 1
    fi

    local -a archives=()
    local file

    while IFS= read -r -d '' file; do
        archives+=("$file")
    done < <(
        find "$archive_dir" -maxdepth 1 \
            -type f -name '*_compact_*_archive.tar.gz' \
            -print0 | sort -z
    )

    if (( ${#archives[@]} == 0 )); then
        echo "$(t MP_EXPORT_INFO_NO_COMPACT_ARCHIVES_FOUND)"
        return 0
    fi

    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "$(t MP_EXPORT_RESTORE_COMPACT_PROJECT "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo
    echo "$(t MP_EXPORT_AVAILABLE_COMPACT_ARCHIVES)"
    echo

    local i
    for i in "${!archives[@]}"; do
        printf '%2d) %s\n' "$((i + 1))" "${archives[$i]##*/}"
    done

    echo
    echo -e "$(t MP_EXPORT_0_CANCEL "${COLOR_YELLOW}" "${COLOR_RESET}")"
    echo

    local choice
    read -rp "$(t MP_EXPORT_SELECT_ARCHIVE)" choice || return 0

    [[ "$choice" == "0" ]] && return 0

    if [[ ! "$choice" =~ ^[0-9]+$ ]] ||
       (( 10#$choice < 1 || 10#$choice > ${#archives[@]} )); then
        log_error "$(t MP_EXPORT_INVALID_ARCHIVE_SELECTION)"
        return 1
    fi

    local archive="${archives[$((10#$choice - 1))]}"

    echo
    echo "$(t MP_EXPORT_SELECTED_ARCHIVE)"
    echo "$archive"
    echo

    # Publish a separately named copy alongside regular projects so existing
    # project selection and deletion menus can manage it.
    local destination="${PROJECT_DIR:?PROJECT_DIR not set}"

    echo
    echo "$(t MP_EXPORT_DESTINATION "$destination")"
    echo "$(t MP_EXPORT_ORIGINAL_ARCHIVE "$archive")"
    echo
    echo "$(t MP_EXPORT_THE_ARCHIVE_AND_ORIGINAL_PROJECT_WILL_NOT_BE_MODIFIED)"
    echo "$(t MP_EXPORT_EXISTING_RESTORED_PROJECT_DIRECTORIES_MUST_REMAIN_UNTOUCHED)"
    echo

    local confirm
    read -rp "$(t MP_EXPORT_TYPE_RESTORE_TO_PROCEED)" confirm || return 0

    if [[ "$confirm" != "RESTORE" ]]; then
        echo "$(t MP_SYS_CANCELLED)"
        return 0
    fi

    mkdir -p -- "$destination" || return 1

    python3 "$worker" "$archive" \
        --projects-dir "$destination"
}

# Remedia MediaPanel: compact/full project archiving.
# Replace ONLY the existing archive_project() function in core/export.sh.
archive_project() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        project_name="$(require_active_project)" || return 1
    fi

    local project_path="$PROJECT_DIR/$project_name"
    [[ -d "$project_path" ]] || { log_error "$(t MP_EXPORT_PROJECT_DIRECTORY_NOT_FOUND "$project_path")"; return 1; }

    local archive_dir="${ARCHIVE_VIDEO_DIR:-${MEDIAPANEL_BACKUPS:-}}"
    [[ -n "$archive_dir" ]] || { log_error "$(t MP_EXPORT_ARCHIVE_DIRECTORY_IS_NOT_CONFIGURED)"; return 1; }

    # Preserve legacy caller semantics: archive_project <project> still asks for mode.
    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "$(t MP_EXPORT_ARCHIVE_PROJECT "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo "$(t MP_EXPORT_PROJECT "$project_name")"
    echo
    echo "$(t MP_EXPORT_1_COMPACT_ARCHIVE_VIDEO_SHORT_EDIT_SUBTITLES_EMPTY_MEDIA)"
    echo "$(t MP_EXPORT_2_FULL_ARCHIVE_ALL_PROJECT_FILES)"
    echo "$(t MP_EXPORT_3_CHECK_SHOTCUT_PROJECT_DEPENDENCIES)"
    echo "$(t MP_EXPORT_4_RESTORE_COMPACT_PROJECT)"
    echo
    echo -e "$(t MP_EXPORT_0_CANCEL "${COLOR_YELLOW}" "${COLOR_RESET}")"
    echo
    local mode
    read -rp "$(t MP_EXPORT_CHOICE)" mode || return 0
    case "$mode" in
        0) return 0 ;;
        1|2|3) ;;
        4) restore_compact_project_menu; return $? ;;
        *) log_error "$(t MP_EXPORT_INVALID_ARCHIVE_MODE)"; return 1 ;;
    esac

    # Check all MLT files: resources, stabilization data, fonts/assets etc.
    # A compact archive is blocked on unresolved in-project file references;
    # this check is conservative and never changes project files.
    local checker="${REMEDIA_LIB:-}/modules/mediapanel/core/archive_mlt_check.py"
    if [[ ! -f "$checker" && -f "$MODULE_DIR/core/archive_mlt_check.py" ]]; then
        checker="$MODULE_DIR/core/archive_mlt_check.py"
    fi
    [[ -f "$checker" ]] || { log_error "$(t MP_EXPORT_MLT_CHECKER_MISSING "$checker")"; return 1; }

    local -a keep_dirs=(video short edit subtitles audio)
    if [[ "$mode" == 1 || "$mode" == 3 ]]; then
        if ! python3 "$checker" "$project_path" "${keep_dirs[@]}"; then
            echo "$(t MP_EXPORT_WARN_COMPACT_ARCHIVE_CANNOT_GUARANTEE_SHOTCUT_PROJECT_INTEGRITY)"
            if [[ "$mode" == 3 ]]; then return 1; fi
            echo "$(t MP_EXPORT_CHOOSE_FULL_ARCHIVE_UNTIL_THE_MLT_REFERENCES_ARE_REPAIRED)"
            return 1
        fi
        [[ "$mode" == 3 ]] && return 0
    fi

    mkdir -p -- "$archive_dir" || return 1
    local stamp suffix archive temp
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    suffix=full
    [[ "$mode" == 1 ]] && suffix=compact
    archive="$archive_dir/${project_name}_${suffix}_${stamp}_$$_archive.tar.gz"
    temp="$(mktemp "$archive_dir/.remedia-archive-XXXXXXXX.tar.gz")" || return 1

    echo
    echo "$(t MP_EXPORT_TARGET "$archive")"
    [[ "$mode" == 1 ]] && echo "$(t MP_EXPORT_COMPACT_ARCHIVE_CONTAINS_ONLY_VIDEO_SHORT_EDIT_SUBTITLES_AND_AN_E)"
    [[ "$mode" != 1 ]] || printf '    + audio/\n'
    [[ "$mode" == 2 ]] && echo "$(t MP_EXPORT_FULL_ARCHIVE_CONTAINS_THE_COMPLETE_PROJECT)"
    echo "$(t MP_EXPORT_ORIGINAL_PROJECT_WILL_NOT_BE_MODIFIED)"
    local confirm
    read -rp "$(t MP_EXPORT_TYPE_ARCHIVE_TO_PROCEED)" confirm || { rm -f -- "$temp"; return 0; }
    if [[ "$confirm" != ARCHIVE ]]; then rm -f -- "$temp"; echo "$(t MP_SYS_CANCELLED)"; return 0; fi

    local rc=0
    if [[ "$mode" == 2 ]]; then
        tar -czf "$temp" -C "$PROJECT_DIR" -- "$project_name" || rc=$?
    else
        # Preserve project root files (e.g. manifests) and wanted folders.
        # Keep media/ itself but exclude every file/subfolder inside it.
        local -a exclusions=("--exclude=$project_name/media/*")
        local path base
        for path in "$project_path"/*; do
            [[ -d "$path" ]] || continue
            base="${path##*/}"
            case "$base" in
                video|short|edit|subtitles|audio|media) ;;
                *) exclusions+=("--exclude=$project_name/$base") ;;
            esac
        done
        # Tar will record media/ as a directory but not its contents.
        tar -czf "$temp" "${exclusions[@]}" -C "$PROJECT_DIR" -- "$project_name" || rc=$?
    fi

    if (( rc != 0 )) || ! tar -tzf "$temp" >/dev/null; then
        rm -f -- "$temp"
        log_error "$(t MP_EXPORT_ARCHIVE_FAILED_OR_TAR_INTEGRITY_CHECK_FAILED_NO_FINAL_ARCHIVE_CRE)"
        return 1
    fi
    if [[ -e "$archive" ]]; then
        rm -f -- "$temp"
        log_error "$(t MP_EXPORT_ARCHIVE_ALREADY_EXISTS "$archive")"
        return 1
    fi
    if ! mv -n -- "$temp" "$archive"; then
        rm -f -- "$temp"
        log_error "$(t MP_EXPORT_COULD_NOT_FINALIZE_ARCHIVE)"
        return 1
    fi
    log_info "$(t MP_EXPORT_PROJECT_ARCHIVED "$project_name")"
    log_info "$(t MP_EXPORT_ARCHIVE_SAVED "$archive")"
}
