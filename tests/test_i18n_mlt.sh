#!/usr/bin/env bash
set -euo pipefail
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
source "$bundle/core/i18n.sh"
i18n_load "$bundle/modules/mediapanel/i18n"
project='001_Test_{1}_100%'
path="$temporary/$project"
mkdir -p "$path/edit" "$path/scenes" "$path/video" "$path/short"
printf 'mock' > "$path/edit/clip.mp4"
printf 'mock' > "$path/scenes/scene.mp4"
ffprobe() {
    local field='' arg
    for arg in "$@"; do
        case "$arg" in
            stream=width) field=1920 ;;
            stream=height) field=1080 ;;
            stream=r_frame_rate) field=25/1 ;;
            stream=sample_aspect_ratio) field=1:1 ;;
            stream=display_aspect_ratio) field=16:9 ;;
            format=duration) field=2.0 ;;
        esac
    done
    printf '%s\n' "$field"
}
generate_files() {
    if ! create_mlt_from_edit "$project" "$path"; then return 1; fi
    if ! create_mlt_from_scenes "$project" "$path"; then return 1; fi
}
if [[ -n "${1:-}" ]]; then
    # Optional supplied original production.sh provides the pre-i18n baseline.
    source "$1"
    generate_files > "$temporary/original.log"
    cp "$path/video/${project}_video.mlt" "$temporary/original-video.mlt"
    cp "$path/short/${project}_short.mlt" "$temporary/original-short.mlt"
    rm "$path/video/${project}_video.mlt" "$path/short/${project}_short.mlt"
fi
source "$bundle/modules/mediapanel/core/production.sh"
for language in en ru kk; do
    export REM_MEDIA_LANG="$language"
    i18n_reload
    generate_files > "$temporary/$language.log"
    if [[ "$language" == en ]]; then
        cp "$path/video/${project}_video.mlt" "$temporary/en-video.mlt"
        cp "$path/short/${project}_short.mlt" "$temporary/en-short.mlt"
        if [[ -n "${1:-}" ]]; then
            cmp "$temporary/original-video.mlt" "$temporary/en-video.mlt"
            cmp "$temporary/original-short.mlt" "$temporary/en-short.mlt"
            cmp "$temporary/original.log" "$temporary/en.log"
        fi
    else
        cmp "$temporary/en-video.mlt" "$path/video/${project}_video.mlt"
        cmp "$temporary/en-short.mlt" "$path/short/${project}_short.mlt"
    fi
    if create_mlt_from_edit "$project" "$path" > /dev/null; then exit 1; else [[ $? == 2 ]]; fi
    cmp "$temporary/en-video.mlt" "$path/video/${project}_video.mlt"
    rm "$path/video/${project}_video.mlt" "$path/short/${project}_short.mlt"
done
python3 - "$temporary/en-video.mlt" "$temporary/en-short.mlt" <<'PY'
import sys,xml.etree.ElementTree as ET
for path in sys.argv[1:]:
    root=ET.parse(path).getroot(); assert root.tag=='mlt'
    assert root.find('profile') is not None
PY
grep -q 'профиль' "$temporary/ru.log"
grep -q 'профиль' "$temporary/kk.log"
echo 'PASS: MLT bytes are locale independent; existing projects stay protected'
