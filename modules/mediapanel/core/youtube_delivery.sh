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
        log_error "YouTube Python environment not found: $python_bin"
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
    echo "                 YOUTUBE QUEUE STATUS"
    echo "===================================================="
    echo

    if [[ ! -d "$queue_dir" ]]; then
        echo "YouTube delivery queue does not exist."
        return 0
    fi

    python3 - "$queue_dir" <<'PY'
import json
import sys
from collections import Counter
from pathlib import Path

queue = Path(sys.argv[1])
jobs = sorted(queue.glob("*.json"))

if not jobs:
    print("Delivery queue is empty.")
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
            f"{names[0] if names else '(no media)'}"
        )

        for name in names[1:]:
            print(f"    + {name}")

        print()
        summary[status.lower()] += 1

    except (OSError, ValueError, TypeError) as exc:
        print(f" {index}) [INVALID] {path.name}")
        print(f"    Error: {exc}")
        print()
        summary["invalid"] += 1

print("-" * 52)
print(f"Total jobs: {len(jobs)}")
print(f"  Completed: {summary['completed']}")
print(f"  Queued:    {summary['queued']}")
print(f"  Failed:    {summary['failed']}")

if summary["invalid"]:
    print(f"  Invalid:   {summary['invalid']}")

other = sum(
    count for status, count in summary.items()
    if status not in ("completed", "queued", "failed", "invalid")
)
if other:
    print(f"  Other:     {other}")

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
        log_warn "YouTube delivery queue does not exist"
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
        python3 - "$queue_dir" <<'PY'
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
            label += f" (+{len(names) - 1} more)"

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
        echo "No queued or failed YouTube jobs."
        return 0
    fi

    echo
    echo "===================================================="
    echo "                 PROCESS YOUTUBE QUEUE"
    echo "===================================================="
    echo

    for ((i=0; i<${#jobs[@]}; i++)); do
        printf '%2d) %s\n' "$((i + 1))" "${labels[i]}"
    done

    echo
    echo "0) Cancel"
    echo

    read -rp "Select job: " choice

    [[ "$choice" == "0" ]] && return 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
       (( 10#$choice < 1 || 10#$choice > ${#jobs[@]} )); then
        log_error "Invalid job selection"
        return 1
    fi

    job="${jobs[$((10#$choice - 1))]}"

    echo
    echo "Selected job:"
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
            log_info "Job already completed"
            return 0
            ;;
        queued|failed)
            ;;
        *)
            log_warn "Job requires review: $job_status"
            return 1
            ;;
    esac

    echo "WARNING: This operation uploads media to YouTube."
    echo "Visibility is determined by each media JSON file."
    echo

    read -rp "Type UPLOAD to confirm: " confirm

    if [[ "$confirm" != "UPLOAD" ]]; then
        log_info "YouTube delivery cancelled"
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
    [[ -d "$queue_dir" ]] || { printf 'Queue directory not found.\n'; return 0; }

    mapfile -d '' -t jobs < <(find "$queue_dir" -maxdepth 1 -type f ! -type l -name '*.json' -print0 | sort -z)
    ((${#jobs[@]})) || { printf 'No jobs to archive.\n'; return 0; }
    printf '\n====================================================\n'
    printf '               ARCHIVE YOUTUBE JOB\n'
    printf '====================================================\n\n'
    local i
    for i in "${!jobs[@]}"; do
        printf '%2d) ' "$((i+1))"
        python3 - "${jobs[i]}" <<'PY'
import json, sys
from pathlib import Path
try:
    with open(sys.argv[1], encoding='utf-8') as stream:
        job=json.load(stream)
    status=str(job.get('status', 'unknown')).upper()
    items=job.get('items', [])
    if not isinstance(items,list): items=[]
    names=[Path(x['media_file']).name for x in items if isinstance(x,dict) and isinstance(x.get('media_file'),str)]
    print(f'[{status}] {names[0] if names else Path(sys.argv[1]).name}' + (f' (+{len(names)-1} more)' if len(names)>1 else ''))
except (ValueError, OSError, TypeError):
    print('[INVALID] ' + Path(sys.argv[1]).name)
PY
    done
    printf '\n0) Cancel\n\n'
    read -r -p 'Select job: ' selection || return 0
    [[ "$selection" == 0 ]] && return 0
    [[ "$selection" =~ ^[0-9]+$ ]] && ((${#selection} < 10)) && ((10#$selection >= 1 && 10#$selection <= ${#jobs[@]})) || {
        printf '[ERROR] Invalid job selection.\n' >&2; return 1;
    }
    job="${jobs[$((10#$selection - 1))]}"
    # Restrict to regular files and prevent symlink substitution.
    [[ -f "$job" && ! -L "$job" ]] || { printf '[ERROR] Job file changed.\n' >&2; return 1; }
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
        *) printf '[BLOCKED] Job status %s cannot be archived.\n' "$status"; return 1 ;;
    esac
    printf '\nSelected: %s\nStatus: %s\n' "$(basename -- "$job")" "$status"
    printf 'Referenced media:\n'
    python3 - "$job" <<'PY'
import json,sys
from pathlib import Path
with open(sys.argv[1], encoding='utf-8') as f: j=json.load(f)
for x in j.get('items',[]):
    if isinstance(x,dict) and isinstance(x.get('media_file'),str):
        print('  - ' + Path(x['media_file']).name)
PY
    printf '\nOnly the job JSON will move. Media and metadata will be untouched.\n'
    if [[ "$status" != completed ]]; then
        printf '[WARNING] %s job is not completed. Archiving removes it from processing queue.\n' "$status"
        read -r -p 'Type REMOVE_FROM_QUEUE to acknowledge: ' extra || return 0
        [[ "$extra" == REMOVE_FROM_QUEUE ]] || { printf 'Cancelled.\n'; return 0; }
    fi
    read -r -p 'Type ARCHIVE to confirm: ' confirm || return 0
    [[ "$confirm" == ARCHIVE ]] || { printf 'Cancelled.\n'; return 0; }
    # Refuse to overwrite any existing archived job.
    mkdir -p -m 700 -- "$archive_dir" || return 1
    local destination="$archive_dir/$(basename -- "$job")"
    [[ ! -e "$destination" && ! -L "$destination" ]] || { printf '[ERROR] Archive target already exists.\n' >&2; return 1; }
    # GNU mv --no-clobber prevents overwriting an existing file.
    mv -n -- "$job" "$destination" || return 1
    if [[ -e "$job" || ! -f "$destination" ]]; then
        printf '[ERROR] Archive did not complete.\n' >&2
        return 1
    fi
    chmod 600 -- "$destination" || return 1
    printf '[OK] Archived job: %s\n' "$destination"
}
