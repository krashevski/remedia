#!/usr/bin/env bash
# modules/mediapanel/core/youtube_delivery.sh
#
# MediaPanel YouTube Delivery Controller
# UI -> Bash Controller -> Python Worker

# ============================================================
# RUNTIME
# ============================================================

youtube_worker_python() {
    local python_bin="${REMEDIA_YOUTUBE_PYTHON:-$HOME/.local/share/remedia/youtube-venv/bin/python}"

    if [[ ! -x "$python_bin" ]]; then
        log_error "$(t MP_YOUTUBE_DELIVERY_YOUTUBE_PYTHON_ENVIRONMENT_NOT_FOUND "$python_bin")" >&2
        return 1
    fi

    printf '%s\n' "$python_bin"
}

youtube_delivery_queue_dir() {
    printf '%s/delivery/queue\n' \
        "${STATE_DIR:-${MEDIAPANEL_VAR:-$HOME/.remedia/mediapanel}}"
}

# ============================================================
# MANUAL YOUTUBE UPLOAD
# ============================================================

manual_youtube_upload() {
    DELIVERY_ROUTE_MODE=manual export_youtube
}

# ============================================================
# EXPORT YOUTUBE TO QUEUE
# ============================================================

export_youtube_queue() {
    DELIVERY_ROUTE_MODE=queue export_youtube
}

# ============================================================
# YOUTUBE QUEUE STATUS
# ============================================================

youtube_queue_status() {
    local queue_dir
    queue_dir="$(youtube_delivery_queue_dir)"

    echo
    echo "===================================================="
    echo "$(t MP_YOUTUBE_DELIVERY_YOUTUBE_QUEUE_STATUS)"
    echo "===================================================="
    echo

    if [[ ! -d "$queue_dir" ]]; then
        echo "$(t MP_YOUTUBE_DELIVERY_YOUTUBE_DELIVERY_QUEUE_DOES_NOT_EXIST)"
        return 0
    fi

    MP_I18N_EMPTY="$(t MP_QUEUE_EMPTY)" \
    MP_I18N_NO_MEDIA="$(t MP_QUEUE_NO_MEDIA)" \
    MP_I18N_ERROR="$(t MP_QUEUE_ERROR)" \
    MP_I18N_TOTAL="$(t MP_QUEUE_TOTAL)" \
    MP_I18N_COMPLETED="$(t MP_QUEUE_COMPLETED)" \
    MP_I18N_QUEUED="$(t MP_QUEUE_QUEUED)" \
    MP_I18N_FAILED="$(t MP_QUEUE_FAILED)" \
    MP_I18N_INVALID="$(t MP_QUEUE_INVALID)" \
    MP_I18N_OTHER="$(t MP_QUEUE_OTHER)" \
    MP_I18N_MORE="$(t MP_QUEUE_MORE)" \
    python3 - "$queue_dir" <<'PY'
import os, re
def ui_text(key, *args):
    text = os.environ["MP_I18N_" + key]
    return re.sub(r"\{([1-9])\}", lambda m: str(args[int(m[1])-1]) if int(m[1]) <= len(args) else m[0], text)
import json
import sys
from collections import Counter
from pathlib import Path

queue = Path(sys.argv[1])
jobs = sorted(queue.glob("*.json"))

if not jobs:
    print(ui_text("EMPTY"))
    raise SystemExit(0)

summary = Counter()

for index, path in enumerate(jobs, start=1):
    try:
        with path.open(encoding="utf-8") as stream:
            job = json.load(stream)

        status = str(job.get("status", "unknown")).upper()
        items = job.get("items", [])

        if not isinstance(items, list):
            items = []

        names = [
            Path(item["media_file"]).name
            for item in items
            if isinstance(item, dict)
            and isinstance(item.get("media_file"), str)
        ]

        print(
            f" {index}) [{status}] "
            f"{names[0] if names else ui_text('NO_MEDIA')}"
        )

        for name in names[1:]:
            print(f"    + {name}")

        print()
        summary[status.lower()] += 1

    except (OSError, ValueError, TypeError) as exc:
        print(f" {index}) [INVALID] {path.name}")
        print(ui_text("ERROR", exc))
        print()
        summary["invalid"] += 1

print("-" * 52)
print(ui_text("TOTAL", len(jobs)))
print(ui_text("COMPLETED", summary['completed']))
print(ui_text("QUEUED", summary['queued']))
print(ui_text("FAILED", summary['failed']))

if summary["invalid"]:
    print(ui_text("INVALID", summary['invalid']))

other = sum(
    count for status, count in summary.items()
    if status not in ("completed", "queued", "failed", "invalid")
)
if other:
    print(ui_text("OTHER", other))

print("=" * 52)
PY
}

# ============================================================
# PROCESS YOUTUBE QUEUE
# ============================================================

process_youtube_queue() {
    local queue_dir
    local python_bin

    queue_dir="$(youtube_delivery_queue_dir)"

    python_bin="$(youtube_worker_python)" || return 1

    if [[ ! -d "$queue_dir" ]]; then
        log_warn "$(t MP_YOUTUBE_DELIVERY_YOUTUBE_DELIVERY_QUEUE_DOES_NOT_EXIST_2)"
        return 0
    fi

    local -a jobs=()
    local -a labels=()
    local job
    local choice
    local confirm

    # Collect only queued and failed jobs.
    # Return NUL-separated pairs: job path, display label.
    local -a entries=()

    mapfile -d '' -t entries < <(
        MP_I18N_MORE="$(t MP_QUEUE_MORE)" \
        python3 - "$queue_dir" <<'PY'
import os, re
def ui_text(key, *args):
    text = os.environ["MP_I18N_" + key]
    return re.sub(r"\{([1-9])\}", lambda m: str(args[int(m[1])-1]) if int(m[1]) <= len(args) else m[0], text)
import json
import sys
from pathlib import Path

queue_dir = Path(sys.argv[1])

for path in sorted(queue_dir.glob("*.json")):
    try:
        with path.open(encoding="utf-8") as stream:
            job = json.load(stream)

        status = job.get("status", "").lower()

        if status not in ("queued", "failed"):
            continue

        items = job.get("items", [])

        if not isinstance(items, list) or not items:
            continue

        names = [
            Path(item["media_file"]).name
            for item in items
            if isinstance(item, dict)
            and isinstance(item.get("media_file"), str)
        ]

        if not names:
            continue

        label = names[0]

        if len(names) > 1:
            label += ui_text("MORE", len(names) - 1)

        display = f"[{status.upper()}] {label}"

        sys.stdout.buffer.write(
            str(path).encode("utf-8") + b"\0"
        )
        sys.stdout.buffer.write(
            display.encode("utf-8") + b"\0"
        )

    except (OSError, ValueError, TypeError, KeyError):
        continue
PY
    )

    local i

    for ((i=0; i+1<${#entries[@]}; i+=2)); do
        jobs+=("${entries[i]}")
        labels+=("${entries[i+1]}")
    done

    if (( ${#jobs[@]} == 0 )); then
        echo
        echo "$(t MP_YOUTUBE_DELIVERY_NO_QUEUED_OR_FAILED_YOUTUBE_JOBS)"
        return 0
    fi

    echo
    echo "===================================================="
    echo "$(t MP_YOUTUBE_DELIVERY_PROCESS_YOUTUBE_QUEUE)"
    echo "===================================================="
    echo

    for ((i=0; i<${#jobs[@]}; i++)); do
        printf '%2d) %s\n' "$((i + 1))" "${labels[i]}"
    done

    echo
    echo "$(t MP_SUB_CANCEL_OPTION)"
    echo

    read -rp "$(t MP_YOUTUBE_DELIVERY_SELECT_JOB)" choice

    [[ "$choice" == "0" ]] && return 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       (( 10#$choice < 1 || 10#$choice > ${#jobs[@]} )); then
        log_error "$(t MP_YOUTUBE_DELIVERY_INVALID_JOB_SELECTION)"
        return 1
    fi

    job="${jobs[$((10#$choice - 1))]}"

    echo
    echo "$(t MP_YOUTUBE_DELIVERY_SELECTED_JOB)"
    echo "  $(basename "$job")"
    echo

    # Completed jobs must not be submitted again.
    local job_status

    job_status="$(
        python3 - "$job" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    job = json.load(stream)

print(job.get("status", "unknown"))
PY
    )" || return 1

    case "$job_status" in
        completed)
            log_info "$(t MP_YOUTUBE_DELIVERY_JOB_ALREADY_COMPLETED)"
            return 0
            ;;
        queued|failed)
            ;;
        *)
            log_warn "$(t MP_YOUTUBE_DELIVERY_JOB_REQUIRES_REVIEW "$job_status")"
            return 1
            ;;
    esac

    echo "$(t MP_YOUTUBE_DELIVERY_WARNING_THIS_OPERATION_UPLOADS_MEDIA_TO_YOUTUBE)"
    echo "$(t MP_YOUTUBE_DELIVERY_VISIBILITY_IS_DETERMINED_BY_EACH_MEDIA_JSON_FILE)"
    echo

    read -rp "$(t MP_YOUTUBE_DELIVERY_TYPE_UPLOAD_TO_CONFIRM)" confirm

    if [[ "$confirm" != "UPLOAD" ]]; then
        log_info "$(t MP_YOUTUBE_DELIVERY_YOUTUBE_DELIVERY_CANCELLED)"
        return 0
    fi

    "$python_bin" \
        "$MODULE_DIR/core/youtube_worker.py" \
        --state-dir "${STATE_DIR:-$MEDIAPANEL_VAR}" \
        --job "$job"
}
#!/usr/bin/env bash
# Source from youtube_delivery.sh; archive one selected queue JSON, never media.
archive_youtube_queue_job() {
    local queue_dir archive_dir job selection status confirm extra
    local -a jobs=()
    queue_dir="$(youtube_delivery_queue_dir)" || return 1
    archive_dir="$(dirname -- "$queue_dir")/archived-jobs"
    [[ -d "$queue_dir" ]] || { t MP_QUEUE_DIRECTORY_MISSING; return 0; }

    mapfile -d '' -t jobs < <(find "$queue_dir" -maxdepth 1 -type f ! -type l -name '*.json' -print0 | sort -z)
    ((${#jobs[@]})) || { t MP_QUEUE_NO_ARCHIVE_JOBS; return 0; }
    printf '\n====================================================\n'
    t MP_QUEUE_ARCHIVE_TITLE
    printf '====================================================\n\n'
    local i
    for i in "${!jobs[@]}"; do
        printf '%2d) ' "$((i+1))"
        MP_I18N_MORE="$(t MP_QUEUE_MORE)" \
        python3 - "${jobs[i]}" <<'PY'
import os, re
def ui_text(key, *args):
    text = os.environ["MP_I18N_" + key]
    return re.sub(r"\{([1-9])\}", lambda m: str(args[int(m[1])-1]) if int(m[1]) <= len(args) else m[0], text)
import json, sys
from pathlib import Path
try:
    with open(sys.argv[1], encoding='utf-8') as stream:
        job=json.load(stream)
    status=str(job.get('status', 'unknown')).upper()
    items=job.get('items', [])
    if not isinstance(items,list): items=[]
    names=[Path(x['media_file']).name for x in items if isinstance(x,dict) and isinstance(x.get('media_file'),str)]
    print(f'[{status}] {names[0] if names else Path(sys.argv[1]).name}' + (ui_text('MORE', len(names)-1) if len(names)>1 else ''))
except (ValueError, OSError, TypeError):
    print('[INVALID] ' + Path(sys.argv[1]).name)
PY
    done
    t MP_QUEUE_CANCEL
    read -r -p "$(t MP_YOUTUBE_DELIVERY_SELECT_JOB)" selection || return 0
    [[ "$selection" == 0 ]] && return 0
    [[ "$selection" =~ ^[0-9]+$ ]] && ((${#selection} < 10)) && ((10#$selection >= 1 && 10#$selection <= ${#jobs[@]})) || {
        t MP_QUEUE_INVALID_SELECTION >&2; return 1;
    }
    job="${jobs[$((10#$selection - 1))]}"
    # Restrict to regular files and prevent symlink substitution.
    [[ -f "$job" && ! -L "$job" ]] || { t MP_QUEUE_FILE_CHANGED >&2; return 1; }
    status="$(python3 - "$job" <<'PY'
import json,sys
try:
    with open(sys.argv[1], encoding='utf-8') as f: j=json.load(f)
    print(j.get('status','unknown') if isinstance(j,dict) else 'unknown')
except (ValueError, OSError, TypeError):
    print('invalid')
PY
)" || return 1
    case "$status" in
        completed|queued|failed) ;;
        *) t MP_QUEUE_BLOCKED "$status"; return 1 ;;
    esac
    t MP_QUEUE_SELECTED_STATUS "$(basename -- "$job")" "$status"
    t MP_QUEUE_REFERENCED_MEDIA
    python3 - "$job" <<'PY'
import json,sys
from pathlib import Path
with open(sys.argv[1], encoding='utf-8') as f: j=json.load(f)
for x in j.get('items',[]):
    if isinstance(x,dict) and isinstance(x.get('media_file'),str):
        print('  - ' + Path(x['media_file']).name)
PY
    t MP_QUEUE_ONLY_JSON
    if [[ "$status" != completed ]]; then
        t MP_QUEUE_INCOMPLETE "$status"
        read -r -p "$(t MP_YOUTUBE_DELIVERY_TYPE_REMOVE_FROM_QUEUE_TO_ACKNOWLEDGE)" extra || return 0
        [[ "$extra" == REMOVE_FROM_QUEUE ]] || { t MP_QUEUE_CANCELLED; return 0; }
    fi
    read -r -p "$(t MP_YOUTUBE_DELIVERY_TYPE_ARCHIVE_TO_CONFIRM)" confirm || return 0
    [[ "$confirm" == ARCHIVE ]] || { t MP_QUEUE_CANCELLED; return 0; }
    # Refuse to overwrite any existing archived job.
    mkdir -p -m 700 -- "$archive_dir" || return 1
    local destination="$archive_dir/$(basename -- "$job")"
    [[ ! -e "$destination" && ! -L "$destination" ]] || { t MP_QUEUE_TARGET_EXISTS >&2; return 1; }
    # GNU mv --no-clobber prevents overwriting an existing file.
    mv -n -- "$job" "$destination" || return 1
    if [[ -e "$job" || ! -f "$destination" ]]; then
        t MP_QUEUE_ARCHIVE_FAILED >&2
        return 1
    fi
    chmod 600 -- "$destination" || return 1
    t MP_QUEUE_ARCHIVED "$destination"
}
