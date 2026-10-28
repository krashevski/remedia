#!/usr/bin/env bash
set -euo pipefail

bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
export HOME="$temporary/home"
export XDG_CONFIG_HOME="$temporary/config with spaces"
mkdir -p "$HOME"
unset CLI_LANGUAGE SUBTITLE_LANGUAGE CLI_NO_UI
source "$bundle/modules/mediapanel/core/subtitle_languages.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_failure() { if "$@"; then fail "unexpected success: $*"; fi; }

mediapanel_subtitle_languages_load
[[ "${MEDIAPANEL_SUBTITLE_LANGUAGES[*]}" == 'ru kk en' ]]
[[ ${#MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[@]} == 100 ]]
mediapanel_subtitle_languages_save en ja de fr
config="$(mediapanel_subtitle_languages_file)"
[[ "$(cat "$config")" == 'en ja de fr' ]]
[[ "$(stat -c %a "$config")" == 600 ]]
mediapanel_subtitle_languages_load
[[ "${MEDIAPANEL_SUBTITLE_LANGUAGES[*]}" == 'en ja de fr' ]]
# Fresh process: preferences survive restart without environment exports.
actual="$(bash -c 'source "$1"; mediapanel_subtitle_languages_load; echo "${MEDIAPANEL_SUBTITLE_LANGUAGES[*]}"' bash "$bundle/modules/mediapanel/core/subtitle_languages.sh")"
[[ "$actual" == 'en ja de fr' ]]

expect_failure mediapanel_subtitle_languages_save
expect_failure mediapanel_subtitle_languages_save en ja de fr ru
expect_failure mediapanel_subtitle_languages_save ru ru
expect_failure mediapanel_subtitle_languages_save zz
expect_failure mediapanel_subtitle_languages_save auto
expect_failure mediapanel_subtitle_languages_save kz
[[ "$(cat "$config")" == 'en ja de fr' ]]

# A directory at the config path must not turn a failed save into success.
mv "$config" "$temporary/preferences.saved"
mkdir "$config"
expect_failure mediapanel_subtitle_languages_save ru
[[ -z "$(find "$config" -mindepth 1 -print -quit)" ]]
rmdir "$config"
mv "$temporary/preferences.saved" "$config"

# Literal malicious text is rejected, never evaluated.
printf '%s\n' '$(touch "$HOME/injected")' > "$config"
mediapanel_subtitle_languages_load
[[ ! -e "$HOME/injected" ]]
[[ "${MEDIAPANEL_SUBTITLE_LANGUAGES[*]}" == 'ru kk en' ]]
printf '' > "$config"
mediapanel_subtitle_languages_load
[[ "${MEDIAPANEL_SUBTITLE_LANGUAGES[*]}" == 'ru kk en' ]]
mediapanel_subtitle_languages_save en ja de fr

mediapanel_subtitle_language_select <<< '2'
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == ja ]]
mediapanel_subtitle_language_select <<< '5'
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == auto ]]
mediapanel_subtitle_language_select <<< ''
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == en ]]
if mediapanel_subtitle_language_select <<< '0'; then fail cancel; else [[ $? == 2 ]]; fi
if mediapanel_subtitle_language_select < /dev/null; then fail EOF; else [[ $? == 1 ]]; fi
expect_failure mediapanel_subtitle_language_select <<< '09'
expect_failure mediapanel_subtitle_language_select <<< '1+1'
CLI_NO_UI=1
mediapanel_subtitle_language_select
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == en ]]
SUBTITLE_LANGUAGE=KK
mediapanel_subtitle_language_select
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == kk ]]
CLI_LANGUAGE=auto
mediapanel_subtitle_language_select
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == auto ]]
CLI_LANGUAGE=YUE
mediapanel_subtitle_language_select
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == yue ]]
CLI_LANGUAGE=zz
expect_failure mediapanel_subtitle_language_select
unset CLI_LANGUAGE SUBTITLE_LANGUAGE CLI_NO_UI

mediapanel_subtitle_languages_save ja
mediapanel_subtitle_language_select <<< '2'
[[ "$MEDIAPANEL_SUBTITLE_LANGUAGE" == auto ]]
mediapanel_subtitle_languages_save en ja de fr

# Actual system-status menu integration: save via option 9, then refresh.
export REMEDIA_LIB="$bundle"
export FAST_STORAGE="$temporary/fast" SLOW_STORAGE="$temporary/slow" BACKUP_STORAGE="$temporary/backup"
export PROJECT_DIR="$temporary/projects"
export COLOR_BOLD='' COLOR_CYAN='' COLOR_GREEN='' COLOR_RED='' COLOR_RESET='' COLOR_YELLOW=''
source "$bundle/modules/mediapanel/ui/system.sh"
clear() { :; }
get_active_project() { printf '%s\n' test_project; }
get_gpu_cached() { printf '%s\n' test_gpu; }
df() { :; }
phone_status() { :; }
show_shotcut_config_status() { mediapanel_subtitle_languages_status; }
output="$(system_status <<< $'9\nru,kk,en,ja\n0')"
[[ "$output" == *'9) Subtitle languages'* ]]
[[ "$output" == *'Russian (ru), Kazakh (kk), English (en), Japanese (ja)'* ]]
mediapanel_subtitle_languages_load
[[ "${MEDIAPANEL_SUBTITLE_LANGUAGES[*]}" == 'ru kk en ja' ]]
# Cancel and EOF preserve settings; invalid entry is rejected before a valid retry.
mediapanel_subtitle_languages_menu <<< '0'
mediapanel_subtitle_languages_menu < /dev/null
[[ "$(cat "$config")" == 'ru kk en ja' ]]
mediapanel_subtitle_languages_menu <<< $'ru ru\nen ja'
[[ "$(cat "$config")" == 'en ja' ]]
mediapanel_subtitle_languages_menu <<< 'r'
[[ "$(cat "$config")" == 'ru kk en' ]]

# End-to-end generation with mocked MLT and Whisper, no GPU/model download.
source "$bundle/modules/mediapanel/core/generate_subtitles.sh"
require_active_project() { printf '%s\n' test_project; }
log_info() { :; }
log_project() { :; }
mediapanel_log_error() { :; }
melt() {
    if [[ "${1:-}" == -version ]]; then echo 'mock melt'; return 0; fi
    local arg
    for arg in "$@"; do
        if [[ "$arg" == avformat:* ]]; then printf 'mock audio' > "${arg#avformat:}"; fi
    done
}
whisper-cli() {
    [[ "${1:-}" != --help ]] || return 0
    local output='' language=''
    while (( $# )); do
        case "$1" in
            -of) output="$2"; shift 2 ;;
            -l) language="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    printf '%s\n' "$language" > "$temporary/whisper-language"
    printf '1\n00:00:00,000 --> 00:00:01,000\nMock subtitle\n\n' > "$output.srt"
}
mkdir -p "$PROJECT_DIR/test_project/video"
printf '<mlt/>' > "$PROJECT_DIR/test_project/video/sample.mlt"
model="$HOME/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/extensions/whispermodel/ggml-large-v3-q5_0.bin"
mkdir -p "${model%/*}"
printf 'mock model' > "$model"
mediapanel_subtitle_languages_save en ja de fr
if ! generate_subtitles <<< $'1\n2' > "$temporary/generation.log"; then
    cat "$temporary/generation.log"; fail generation
fi
[[ "$(cat "$temporary/whisper-language")" == ja ]]
[[ -s "$PROJECT_DIR/test_project/subtitles/sample/subtitles_final.srt" ]]
# CLI override takes priority even if absent from the preferred menu.
CLI_LANGUAGE=kk
if ! generate_subtitles <<< '1' > "$temporary/override.log"; then fail override; fi
[[ "$(cat "$temporary/whisper-language")" == kk ]]
unset CLI_LANGUAGE
rm "$temporary/whisper-language"
if ! generate_subtitles <<< $'1\n0' > "$temporary/cancel.log"; then fail generation_cancel; fi
[[ ! -e "$temporary/whisper-language" ]]

# Both entry points can load the helper on their own in a new shell.
bash -eu -c 'source "$1"; declare -F mediapanel_subtitle_languages_load >/dev/null' bash "$bundle/modules/mediapanel/core/generate_subtitles.sh"
bash -eu -c 'source "$1"; declare -F mediapanel_subtitle_languages_load >/dev/null' bash "$bundle/modules/mediapanel/ui/system.sh"

echo 'PASS: preferences, restart, validation, menus, overrides and mocked generation'
