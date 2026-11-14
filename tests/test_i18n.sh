#!/usr/bin/env bash
set -euo pipefail

bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
export HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/config"
mkdir -p "$HOME" "$temporary/first" "$temporary/second"
source "$bundle/core/i18n.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
equal() { [[ "$1" == "$2" ]] || fail "expected [$2], got [$1]"; }
reject() { if "$@"; then fail "unexpected success: $*"; fi; }

cat > "$temporary/first/en.env" <<'ENV'
# Quoted values, not shell code.
TEST_HELLO="Hello {1}; {2}"
TEST_FALLBACK="English fallback"
TEST_EMPTY="Nonempty English"
TEST_LITERAL='$(touch "$HOME/injected") `touch "$HOME/injected"` $HOME'
TEST_ESCAPES="line1\nline2\t\"quoted\"\\end"
ENV
cat > "$temporary/first/ru.env" <<'ENV'
TEST_HELLO="Привет, {1}; {2}"
TEST_EMPTY=""
ENV
cat > "$temporary/first/kk.env" <<'ENV'
TEST_HELLO="Сәлем, {1}; {2}"
ENV
cat > "$temporary/second/en.env" <<'ENV'
SECOND_LABEL="Second module"
ENV

LANG=en_US.UTF-8 REM_MEDIA_LANG=ru_RU.UTF-8
i18n_load "$temporary/first"
equal "$(t TEST_HELLO World '100% & {1} \\ $HOME')" 'Привет, World; 100% & {1} \\ $HOME'
equal "$(t TEST_FALLBACK)" 'English fallback'
equal "$(t TEST_EMPTY)" 'Nonempty English'
equal "$(t TEST_MISSING)" TEST_MISSING
equal "$(t TEST_ESCAPES)" $'line1\nline2\t"quoted"\\end'
equal "$(t TEST_LITERAL)" '$(touch "$HOME/injected") `touch "$HOME/injected"` $HOME'
[[ ! -e "$HOME/injected" ]]
reject t 'invalid[key]'

# Override > system locale > English, including regional locale normalization.
REM_MEDIA_LANG=fr_FR.UTF-8 LANG=ru_RU.UTF-8
i18n_reload
equal "$(t TEST_HELLO A B)" 'Привет, A; B'
REM_MEDIA_LANG=kk-KZ.UTF-8
i18n_reload
equal "$(t TEST_HELLO A B)" 'Сәлем, A; B'
REM_MEDIA_LANG=kz_KZ.UTF-8
i18n_reload
equal "$(t TEST_HELLO A B)" 'Сәлем, A; B'
unset REM_MEDIA_LANG
LANG=C.UTF-8
i18n_reload
equal "$(t TEST_HELLO A B)" 'Hello A; B'
unset LANG
i18n_reload
equal "$(t TEST_HELLO A B)" 'Hello A; B'
REM_MEDIA_LANG='../../bad'
i18n_reload
equal "$(t TEST_HELLO A B)" 'Hello A; B'
unset REM_MEDIA_LANG

# Idempotent runtime sourcing and module registration preserve translations.
source "$bundle/core/i18n.sh"
i18n_load "$temporary/first"
equal "${#I18N_PATHS[@]}" 1
i18n_load "$temporary/second"
equal "$(t SECOND_LABEL)" 'Second module'
equal "$(t TEST_HELLO A B)" 'Hello A; B'

# Reject collisions, duplicate keys, executable syntax and malformed strings.
cp "$temporary/second/en.env" "$temporary/second.saved"
printf 'TEST_HELLO="collision"\n' > "$temporary/second/en.env"
reject i18n_reload
equal "$(t SECOND_LABEL)" 'Second module'
printf 'SECOND_LABEL="a"\nSECOND_LABEL="b"\n' > "$temporary/second/en.env"
reject i18n_reload
printf 'source /etc/passwd\n' > "$temporary/second/en.env"
reject i18n_reload
printf 'SECOND_LABEL="bad\\q"\n' > "$temporary/second/en.env"
reject i18n_reload
printf 'SECOND_LABEL="unterminated\n' > "$temporary/second/en.env"
reject i18n_reload
cp "$temporary/second.saved" "$temporary/second/en.env"
printf 'UNDECLARED="not in English"\n' > "$temporary/second/ru.env"
REM_MEDIA_LANG=ru
reject i18n_reload
equal "$(t SECOND_LABEL)" 'Second module'
rm "$temporary/second/ru.env"
unset REM_MEDIA_LANG

# Runtime resolution and formatting use Bash builtins only, without PATH tools.
saved_path="$PATH"
PATH=/no-external-commands
i18n_reload
equal "$(t TEST_HELLO A B)" 'Hello A; B'
PATH="$saved_path"

# Verify real dictionaries have matching keys and placeholder multiplicities.
declare -A english=() translated=()
i18n_read_file "$bundle/modules/mediapanel/i18n/en.env" english
equal "${#english[@]}" 916
placeholder_signature() {
    local value="$1" prefix
    while [[ "$value" == *\{[1-9]\}* ]]; do
        prefix="${value%%\{[1-9]\}*}"
        value="${value:${#prefix}}"
        printf '%s\n' "${value:0:3}"
        value="${value:3}"
    done | LC_ALL=C sort
}
for language in ru kk; do
    translated=()
    i18n_read_file "$bundle/modules/mediapanel/i18n/$language.env" translated
    equal "${#translated[@]}" "${#english[@]}"
    for key in "${!english[@]}"; do
        [[ -n "${translated[$key]+present}" ]] || fail "missing $language/$key"
        equal "$(placeholder_signature "${translated[$key]}")" "$(placeholder_signature "${english[$key]}")"
    done
done

# Menu smoke tests: avoid running external Remedia operations.
export REMEDIA_LIB="$bundle" FAST_STORAGE="$temporary/fast" SLOW_STORAGE="$temporary/slow"
export BACKUP_STORAGE="$temporary/backup" PROJECT_DIR="$temporary/projects" REMEDIA_VAR="$temporary/var"
export COLOR_BOLD='' COLOR_CYAN='' COLOR_GREEN='' COLOR_RED='' COLOR_RESET='' COLOR_YELLOW=''
clear() { :; }
get_active_project() { printf '%s\n' 'test_project'; }
get_gpu_cached() { printf '%s\n' test_gpu; }
df() { :; }
# Stop using fixture dictionaries and register the real module.
I18N_PATHS=() I18N=() I18N_EN=()
export REM_MEDIA_LANG=ru LANG=en_US.UTF-8
i18n_load "$bundle/modules/mediapanel/i18n"
source "$bundle/modules/mediapanel/ui/ui.sh"
source "$bundle/modules/mediapanel/ui/system.sh"
phone_status() { :; }
show_shotcut_config_status() { mediapanel_subtitle_languages_status; }
output="$(main_menu <<< '0')"
[[ "$output" == *'1) Состояние системы'* && "$output" == *'0) Выход'* ]]
output="$(system_status <<< '0')"
[[ "$output" == *'9) Языки субтитров'* && "$output" == *'Русский (ru), Казахский (kk), Английский (en)'* ]]
REM_MEDIA_LANG=kk
i18n_reload
output="$(main_menu <<< '0')"
[[ "$output" == *'1) Жүйе күйі'* && "$output" == *'0) Шығу'* ]]
output="$(system_status <<< '0')"
[[ "$output" == *'9) Субтитр тілдері'* && "$output" == *'Орыс (ru), Қазақ (kk), Ағылшын (en)'* ]]
[[ "$output" != *'MP_SYS_'* && "$output" != *'{1}'* ]]

# UI locale affects labels, never the chosen Whisper language code.
unset CLI_LANGUAGE SUBTITLE_LANGUAGE
CLI_NO_UI=1
mediapanel_subtitle_language_select
equal "$MEDIAPANEL_SUBTITLE_LANGUAGE" ru
CLI_LANGUAGE=en
mediapanel_subtitle_language_select
equal "$MEDIAPANEL_SUBTITLE_LANGUAGE" en
echo 'PASS: i18n fallback, safe parsing, placeholders, module isolation and RU/KK menus'
