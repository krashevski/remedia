#!/usr/bin/env bash
set -euo pipefail
bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
mkdir -p "$temporary/modules/plain" "$temporary/modules/parent/modules/child"
ln -s "$bundle/core" "$temporary/core"
ln -s "$bundle/modules/mediapanel" "$temporary/modules/mediapanel"
printf 'NAME=plain\nDESC=Plain module description\nCATEGORY=media' > "$temporary/modules/plain/module.meta"
printf 'run=Run plain task' > "$temporary/modules/plain/commands.meta"
printf 'NAME=child\nDESC=Child module\nCATEGORY=media\n' > "$temporary/modules/parent/modules/child/module.meta"
touch "$temporary/modules/parent/modules/child/task.sh"
export REMEDIA_LIB="$temporary" LANG=en_US.UTF-8

for language in en ru kk; do
    export REM_MEDIA_LANG="$language"
    bash -eu -c 'source "$1/core/help.sh"; remedia_help' bash "$bundle" > "$temporary/root-$language"
    bash -eu -c 'source "$1/core/help.sh"; remedia_module_help mediapanel' bash "$bundle" > "$temporary/media-$language"
    bash -eu -c 'source "$1/core/help.sh"; remedia_module_help plain' bash "$bundle" > "$temporary/plain-$language"
    bash -eu -c 'source "$1/core/help.sh"; remedia_module_help child parent' bash "$bundle" > "$temporary/child-$language"
    grep -q 'Plain module description' "$temporary/root-$language"
    grep -q 'Run plain task' "$temporary/plain-$language"
    grep -q 'remedia parent child' "$temporary/child-$language"
    if bash -eu -c 'source "$1/core/help.sh"; remedia_module_help absent' bash "$bundle" > "$temporary/error-$language"; then
        exit 1
    fi
done
grep -q 'Доступные команды:' "$temporary/root-ru"
grep -q 'панель для видеомонтажа' "$temporary/root-ru"
grep -q 'интерактивный пользовательский интерфейс' "$temporary/media-ru"
grep -q 'Использование:' "$temporary/media-ru"
grep -q 'Қолжетімді пәрмендер:' "$temporary/root-kk"
grep -q 'бейнемонтаж' "$temporary/root-kk"
grep -q 'интерактивті пайдаланушы интерфейсі' "$temporary/media-kk"
grep -q 'Қолданылуы:' "$temporary/media-kk"

# Source both core and module dictionaries together to check namespace isolation.
bash -eu -c 'source "$1/core/i18n.sh"; i18n_load "$1/core/i18n"; i18n_load "$1/modules/mediapanel/i18n"; [[ ${#I18N_EN[@]} == 873 ]]' bash "$bundle"
echo 'PASS: EN/RU/KK core/module help, metadata selection, canonical fallback and nested modules'
