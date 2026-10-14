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
            "python3 is required to create JSON metadata"
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
            "Failed to create metadata: $metadata_file"
        return 1
    fi

    log_info "Metadata saved: $metadata_file"

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
            "Metadata file not found: $metadata_file"
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
    echo "=================================================="
    echo " MANUAL UPLOAD MODE"
    echo "=================================================="

    for file in "$@"; do
        metadata_file="${file%.*}.youtube.json"

        if [[ ! -f "$metadata_file" ]]; then
            log_error \
                "Metadata not found: $metadata_file"
            continue
        fi

        update_delivery_status \
            "$metadata_file" \
            "manual" \
            "ready_for_upload" || continue

        echo
        echo "Media:"
        echo "   $file"
        echo "Metadata:"
        echo "   $metadata_file"
    done

    echo
    echo "👉 Open:"
    echo "   https://studio.youtube.com/upload"
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
        log_error "Failed to create queue: $queue_dir"
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
        log_error "Failed to create delivery job"
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
            "Delivery archive directory is not configured"
        return 1
    fi

    local delivery_archive_dir="$archive_root/delivery"

    mkdir -p "$delivery_archive_dir" || {
        log_error \
            "Failed to create archive directory: $delivery_archive_dir"
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
            log_error "Media not found: $file"
            return 1
        fi

        if [[ ! -f "$metadata_file" ]]; then
            log_error \
                "Metadata not found: $metadata_file"
            return 1
        fi

        case "$file" in
            "$project_path"/*)
                ;;
            *)
                log_error \
                    "File is outside project: $file"
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

    log_info "Creating delivery archive:"
    echo "$archive"

    if ! tar -czf "$archive" \
        -C "$project_path" \
        "${archive_items[@]}"; then

        log_error "Failed to create delivery archive"
        return 1
    fi

    for file in "$@"; do
        metadata_file="${file%.*}.youtube.json"

        if ! update_delivery_status \
            "$metadata_file" \
            "archive" \
            "archived"; then

            log_warn \
                "Archive created, but metadata status update failed:"
            echo "$metadata_file"
        fi
    done

    log_info "Delivery archive saved: $archive"

    echo
    echo "Archived files:"

    for file in "$@"; do
        echo "   $(basename "$file")"
    done

    echo
    echo "Archive:"
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
            log_error "Unknown delivery mode: $DELIVERY_ROUTE_MODE"
            return 1
            ;;
    esac

    local file
    local metadata_file

    # Stage 1: validate media and metadata.
    for file in "${files[@]}"; do
        metadata_file="${file%.*}.youtube.json"

        [[ -f "$file" ]] || {
            log_error "Media not found: $file"
            return 1
        }

        [[ -f "$metadata_file" ]] || {
            log_error \
                "Metadata not found: $metadata_file"
            return 1
        }
    done

    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==================================================${COLOR_RESET}"
    echo -e "                 ${COLOR_BOLD}${COLOR_CYAN} DELIVERY ROUTING${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}==================================================${COLOR_RESET}"
    echo "1) Manual YouTube upload"
    echo "2) Add to delivery queue"
    echo "3) Archive deliverables"
    echo
    echo "${COLOR_YELLOW}0) Cancel${COLOR_RESET}"
    echo "=================================================="

    local route=""
    read -rp "Select delivery route: " route

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
            log_info "Delivery cancelled"
            return 0
            ;;
        *)
            log_error "Invalid delivery route"
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
             "No publication-ready MP4 files found in video/ or short/"
        return 1
    fi

    echo
    echo "Available publication files:"
    echo "------------------------------------------------"

    local i=1
    local file
    local label

    for file in "${files[@]}"; do
        case "$file" in
            "$video_dir"/*)
                label="VIDEO"
                ;;
            "$short_dir"/*)
                label="SHORT"
                ;;
            *)
                label="UNKNOWN"
                ;;
        esac

        printf '%2d) [%-5s] %s\n' \
            "$i" \
            "$label" \
            "$(basename "$file")"

        ((i++))
    done

    echo "------------------------------------------------"
    echo "Select one or several files."
    echo "Examples: 1   |   1 2   |   all"
    echo

    local selection=""
    if ! IFS= read -r -p "Selection: " selection; then
        log_info "Selection cancelled"
        return 0
    fi

    selection="${selection//,/ }"

    if [[ -z "${selection//[[:space:]]/}" ]]; then
        log_info "Selection cancelled"
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
                    "Invalid selection: $choice"
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
        log_error "No files selected"
        return 1
    fi

    echo
    echo "Selected files:"
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
        echo "Metadata JSON already exists for all selected files."
        echo

        read -rp \
            "Use existing metadata without changes? [Y/n]: " \
            reuse_metadata

        reuse_metadata="${reuse_metadata:-Y}"

        if [[ "$reuse_metadata" =~ ^[YyДд]$ ]]; then
            log_info "Using existing metadata"

            delivery_route \
                "$project" \
                "${selected_files[@]}"

            local result=$?

            pause
            return "$result"
        fi

        log_info "Existing metadata will be recreated"
    fi

    local overwrite_existing="Y"

    if (( existing_metadata > 0 &&
          missing_metadata > 0 )); then

        echo
        echo "Existing metadata: $existing_metadata"
        echo "Missing metadata:  $missing_metadata"
        echo

        read -rp \
            "Recreate existing metadata too? [y/N]: " \
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
    echo "Shared YouTube metadata"
    echo "------------------------------------------------"

    read -rp "Title [$default_title]: " title
    title="${title:-$default_title}"

    echo
    echo "Description:"
    echo "Enter one line at a time."
    echo "Finish with a single dot (.)"
    echo "------------------------------------------------"

    while true; do
        read -rp "> " line || {
            echo
            log_error "Description input interrupted"
            return 1
        }

        [[ "$line" == "." ]] && break

        if [[ -n "$description" ]]; then
            description+=$'\n'
        fi

        description+="$line"
    done

    read -rp \
        "Tags (comma-separated): " \
        tags

    while true; do
        read -rp \
            "Visibility [private/unlisted/public] (private): " \
            visibility

        visibility="${visibility:-private}"

        case "$visibility" in
            private|unlisted|public)
                break
                ;;
            *)
                log_warn \
                    "Allowed values: private, unlisted, public"
                ;;
        esac
    done

    echo
    echo "Creating YouTube metadata..."
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
                "Using existing metadata: $metadata_file"

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
                log_error "Unknown publication type: $file"
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
            "Delivery routing cancelled: metadata errors"
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
        log_error "Restore module not found: $worker"
        return 1
    fi

    if [[ ! -d "$archive_dir" ]]; then
        log_error "Archive directory not found: $archive_dir"
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
        echo "[INFO] No compact archives found."
        return 0
    fi

    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "            ${COLOR_BOLD}${COLOR_CYAN}RESTORE COMPACT PROJECT${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo
    echo "Available compact archives:"
    echo

    local i
    for i in "${!archives[@]}"; do
        printf '%2d) %s\n' "$((i + 1))" "${archives[$i]##*/}"
    done

    echo
    echo -e "${COLOR_YELLOW}0) Cancel${COLOR_RESET}"
    echo

    local choice
    read -rp "Select archive: " choice || return 0

    [[ "$choice" == "0" ]] && return 0

    if [[ ! "$choice" =~ ^[0-9]+$ ]] ||
       (( 10#$choice < 1 || 10#$choice > ${#archives[@]} )); then
        log_error "Invalid archive selection"
        return 1
    fi

    local archive="${archives[$((10#$choice - 1))]}"

    echo
    echo "Selected archive:"
    echo "$archive"
    echo

    local destination
    read -rp "Restore destination [/mnt/shotcut/remedia-restore]: " destination \
        || return 0

    destination="${destination:-/mnt/shotcut/remedia-restore}"

    # Expand ~/ if entered by the user.
    if [[ "$destination" == "~/"* ]]; then
        destination="$HOME/${destination#~/}"
    fi

    local old_root="${PROJECT_DIR}/${project_name:-}"

    echo
    echo "Destination: $destination"
    echo "Original archive: $archive"
    echo
    echo "The archive and original project will not be modified."
    echo "Existing restored project directories must remain untouched."
    echo

    local confirm
    read -rp "Type RESTORE to proceed: " confirm || return 0

    if [[ "$confirm" != "RESTORE" ]]; then
        echo "Cancelled."
        return 0
    fi

    mkdir -p -- "$destination" || return 1

    python3 "$worker" "$archive" \
        --destination "$destination"
}

# Remedia MediaPanel: compact/full project archiving.
# Replace ONLY the existing archive_project() function in core/export.sh.
archive_project() {
    local project_name="${1:-}"
    if [[ -z "$project_name" ]]; then
        project_name="$(require_active_project)" || return 1
    fi

    local project_path="$PROJECT_DIR/$project_name"
    [[ -d "$project_path" ]] || { log_error "Project directory not found: $project_path"; return 1; }

    local archive_dir="${ARCHIVE_VIDEO_DIR:-${MEDIAPANEL_BACKUPS:-}}"
    [[ -n "$archive_dir" ]] || { log_error 'Archive directory is not configured'; return 1; }

    # Preserve legacy caller semantics: archive_project <project> still asks for mode.
    echo
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo -e "                 ${COLOR_BOLD}${COLOR_CYAN}ARCHIVE PROJECT${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
    echo "Project: $project_name"
    echo
    echo '1) Compact archive (video, short, edit, subtitles; empty media)'
    echo '2) Full archive (all project files)'
    echo '3) Check Shotcut project dependencies'
    echo '4) Restore Compact Project'
    echo
    echo -e "${COLOR_YELLOW}0) Cancel${COLOR_RESET}"
    echo
    local mode
    read -rp 'Choice: ' mode || return 0
    case "$mode" in
        0) return 0 ;;
        1|2|3) ;;
        4) restore_compact_project_menu; return $? ;;
        *) log_error 'Invalid archive mode'; return 1 ;;
    esac

    # Check all MLT files: resources, stabilization data, fonts/assets etc.
    # A compact archive is blocked on unresolved in-project file references;
    # this check is conservative and never changes project files.
    local checker="${REMEDIA_LIB:-}/modules/mediapanel/core/archive_mlt_check.py"
    if [[ ! -f "$checker" && -f "$MODULE_DIR/core/archive_mlt_check.py" ]]; then
        checker="$MODULE_DIR/core/archive_mlt_check.py"
    fi
    [[ -f "$checker" ]] || { log_error "MLT checker missing: $checker"; return 1; }

    local -a keep_dirs=(video short edit subtitles)
    if [[ "$mode" == 1 || "$mode" == 3 ]]; then
        if ! python3 "$checker" "$project_path" "${keep_dirs[@]}"; then
            echo '[WARN] Compact archive cannot guarantee Shotcut project integrity.'
            if [[ "$mode" == 3 ]]; then return 1; fi
            echo 'Choose Full archive until the MLT references are repaired.'
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
    echo "Target: $archive"
    [[ "$mode" == 1 ]] && echo 'Compact archive contains only video/, short/, edit/, subtitles/ and an empty media/.'
    [[ "$mode" == 2 ]] && echo 'Full archive contains the complete project.'
    echo 'Original project will not be modified.'
    local confirm
    read -rp 'Type ARCHIVE to proceed: ' confirm || { rm -f -- "$temp"; return 0; }
    if [[ "$confirm" != ARCHIVE ]]; then rm -f -- "$temp"; echo 'Cancelled.'; return 0; fi

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
                video|short|edit|subtitles|media) ;;
                *) exclusions+=("--exclude=$project_name/$base") ;;
            esac
        done
        # Tar will record media/ as a directory but not its contents.
        tar -czf "$temp" "${exclusions[@]}" -C "$PROJECT_DIR" -- "$project_name" || rc=$?
    fi

    if (( rc != 0 )) || ! tar -tzf "$temp" >/dev/null; then
        rm -f -- "$temp"
        log_error 'Archive failed or tar integrity check failed; no final archive created.'
        return 1
    fi
    if [[ -e "$archive" ]]; then
        rm -f -- "$temp"
        log_error "Archive already exists: $archive"
        return 1
    fi
    if ! mv -n -- "$temp" "$archive"; then
        rm -f -- "$temp"
        log_error 'Could not finalize archive'
        return 1
    fi
    log_info "Project archived: $project_name"
    log_info "Archive saved: $archive"
}
