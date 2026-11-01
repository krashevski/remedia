#!/usr/bin/env bash
set -euo pipefail
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
export HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/config"
mkdir -p "$HOME"
source "$bundle/core/i18n.sh"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Test the CLI components under the same centralized i18n setup as entry.sh.
export REMEDIA_LIB="$bundle" MODULE_DIR="$bundle/modules/mediapanel"
export PROJECT_DIR="$temporary/projects" STATE_DIR="$temporary/state" MEDIAPANEL_VAR="$temporary/state"
export RAW_DIR="$temporary/raw" JOURNAL="$temporary/state/journal" MEDIA_DB="$temporary/state/index"
export COLOR_BOLD='' COLOR_CYAN='' COLOR_GREEN='' COLOR_RED='' COLOR_RESET='' COLOR_YELLOW=''
export COLOR_BLUE='' COLOR_MAGENTA='' GREEN='' RED='' RESET='' CYAN='' BOLD=''
mkdir -p "$PROJECT_DIR" "$STATE_DIR" "$RAW_DIR"
log_info() { printf '[INFO] %s\n' "$*" >&2; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
source "$MODULE_DIR/core/project_core.sh"
source "$MODULE_DIR/core/project.sh"
source "$MODULE_DIR/core/api.sh"
source "$MODULE_DIR/core/export.sh"
source "$MODULE_DIR/core/pipeline_state.sh"
source "$MODULE_DIR/core/production.sh"
source "$MODULE_DIR/modules/media_pool.sh"
source "$MODULE_DIR/core/youtube_delivery.sh"

for language in en ru kk; do
    export REM_MEDIA_LANG="$language"
    i18n_reload "$MODULE_DIR/i18n"
    CLI_NO_UI=1 CLI_NAME="case_${language}_100%_{1}"
    name="$(project_core_create)"
    [[ "$name" == *"_$CLI_NAME" && "$name" != *$'\n'* ]] || fail 'project name stdout'
    PROJECT_TEST="$name"
    get_active_project() { printf '%s\n' "$PROJECT_TEST"; }
    [[ "$(require_active_project)" == "$name" ]] || fail 'active project stdout'
    [[ "$(project_paths "$name")" == "$PROJECT_DIR/$name" ]] || fail paths
    [[ "$(pipeline_state_file "$name")" == "$PROJECT_DIR/$name/.pipeline_state" ]] || fail state_path
    [[ "$(pipeline_lock_file "$name")" == "$PROJECT_DIR/$name/.pipeline.lock" ]] || fail lock_path
    pipeline_set "$name" proxy done
    [[ "$(pipeline_get "$name" proxy)" == done ]] || fail state_value
    pipeline_status "$name" > "$temporary/pipeline-$language.log"
    grep -q '^proxy=done$' "$PROJECT_DIR/$name/.pipeline_state" || fail translated_state

    # Failure diagnostics must not become a captured project name.
    CLI_NAME=''
    if project_core_create > "$temporary/stdout" 2> "$temporary/stderr"; then fail empty_name; fi
    [[ ! -s "$temporary/stdout" && -s "$temporary/stderr" ]] || fail error_stream

    media="$PROJECT_DIR/$name/video/name_{1}.mp4"
    printf 'not a real codec; test metadata only' > "$media"
    write_youtube_metadata "$media" video 'Title {1} 100% қазақ' 'Description $HOME' 'tag1,tag2' unlisted
    python3 - "${media%.*}.youtube.json" <<'PY'
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: m=json.load(f)
assert m['title']=='Title {1} 100% қазақ'
assert m['description']=='Description $HOME'
assert m['visibility']=='unlisted' and m['content_type']=='video'
assert m['platform']=='youtube' and m['status']=='prepared'
assert m['tags']==['tag1','tag2']
PY

    # Ingest returns JSON with stable machine error codes, across all locales.
    detect_phone() { return 1; }
    result="$(ingest_from_phone_v3)"
    python3 - "$result" <<'PY'
import json,sys
m=json.loads(sys.argv[1])
assert m['error']=='no_device_or_project'
assert set(m)=={'ok','fail','skip','total','error','runtime_ms'}
PY
    phone="$temporary/phone-$language"
    mkdir "$phone"
    printf 'original media bytes' > "$phone/example.mov"
    detect_phone() { printf '%s\n' "$phone"; }
    result="$(ingest_from_phone_v3)"
    python3 - "$result" <<'PY'
import json,sys
m=json.loads(sys.argv[1]); assert m['ok']==1 and m['fail']==0 and m['error']==''
PY
    cmp "$phone/example.mov" "$PROJECT_DIR/$name/media/example.mov"
    hash="$(sha1sum "$PROJECT_DIR/$name/media/example.mov" | cut -d' ' -f1)"
    [[ "$(media_materialize "$hash" 2> "$temporary/materialize.log")" == "$PROJECT_DIR/$name/media/example.mov" ]] || fail materialize_stdout

    queue="$(youtube_delivery_queue_dir)"
    mkdir -p "$queue"
    printf '%s\n' '{"status":"queued","items":[{"media_file":"a_{1}.mp4"},{"media_file":"b.mp4"}]}' > "$queue/job-$language.json"
    youtube_queue_status > "$temporary/queue-$language.log"
    [[ "$(cat "$temporary/queue-$language.log")" == *'a_{1}.mp4'* ]] || fail queue_filename
    export REMEDIA_YOUTUBE_PYTHON="$(command -v python3)"
    process_youtube_queue <<< '0' > "$temporary/process-$language.log"
    archive_youtube_queue_job <<< '0' > "$temporary/archive-$language.log"
    [[ -f "$queue/job-$language.json" ]] || fail archive_cancel
    # The only selected job is moved; media and metadata must be preserved.
    archive_youtube_queue_job <<< $'1\nREMOVE_FROM_QUEUE\nARCHIVE' > "$temporary/archive-save-$language.log"
    [[ ! -e "$queue/job-$language.json" && -f "${queue%/*}/archived-jobs/job-$language.json" ]] || fail archive_move
    python3 - "${queue%/*}/archived-jobs/job-$language.json" <<'PY'
import json,sys
assert json.load(open(sys.argv[1]))['status']=='queued'
PY
    [[ -f "$media" && -f "${media%.*}.youtube.json" ]] || fail media_preserved
done
grep -q 'Всего заданий:' "$temporary/queue-ru.log"
grep -q 'Барлық тапсырмалар:' "$temporary/queue-kk.log"
grep -q 'ещё 1' "$temporary/process-ru.log"
grep -q 'тағы 1' "$temporary/archive-kk.log"

# Verify dictionaries, placeholder contracts and static references in scripts.
python3 - "$bundle" <<'PY'
import json,re,sys,subprocess
from pathlib import Path
root=Path(sys.argv[1]); catalogs={}
for lang in ('en','ru','kk'):
    data={}
    for line in (root/'modules/mediapanel/i18n'/f'{lang}.env').read_text().splitlines():
        if not line or line.startswith('#'): continue
        k,v=line.split('=',1); assert k not in data; data[k]=json.loads(v)
    catalogs[lang]=data
assert len(catalogs['en'])==859
for lang in ('ru','kk'):
    assert catalogs[lang].keys()==catalogs['en'].keys()
    for k,v in catalogs[lang].items():
        assert sorted(re.findall(r'\{[1-9]\}',v))==sorted(re.findall(r'\{[1-9]\}',catalogs['en'][k])),k
for p in (root/'modules/mediapanel').rglob('*.sh'):
    subprocess.run(['bash','-n',str(p)],check=True)
    for k in re.findall(r'\bt (MP_[A-Z0-9_]+)',p.read_text()): assert k in catalogs['en'],(p,k)
PY
echo 'PASS: EN/RU/KK data contracts, project stdout, JSON, ingest, pipeline and YouTube queue'
