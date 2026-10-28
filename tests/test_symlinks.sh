#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/repo/modules/system" "$test_dir/repo/core"
cp -R "$bundle_dir/modules/system/." "$test_dir/repo/modules/system/"

cat > "$test_dir/repo/core/storage.sh" <<'BASH'
storage_slow() { printf '%s\n' "${SLOW_STORAGE:-/mnt/storage}"; }
BASH

source "$test_dir/repo/modules/system/modules/symlinks.sh"
resolve_target_home() { printf '%s\n' "$TEST_HOME"; }
ui_confirm_policy() { return 1; }
info() { :; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

new_case() {
    TEST_HOME="$test_dir/$1/home"
    SLOW_STORAGE="$test_dir/$1/storage with spaces"
    mkdir -p "$TEST_HOME"
    unset REM_MEDIA_LANG
}
assert_link() {
    [[ -L "$TEST_HOME/$1" ]]
    [[ "$(readlink -- "$TEST_HOME/$1")" == "$SLOW_STORAGE/$2" ]]
}

new_case ru
LANG=ru_RU.UTF-8
system_symlinks_run
assert_link Музыка Music
assert_link Изображения Pictures
assert_link Видео Videos
# Repeat with nounset enabled: configuration must be reusable and idempotent.
system_symlinks_run

new_case override
LANG=ru_RU.UTF-8 REM_MEDIA_LANG=ja-JP
system_symlinks_run
assert_link 音楽 Music

new_case unknown
LANG=fr_FR.UTF-8
system_symlinks_run
assert_link Music Music

new_case unset_lang
unset LANG
system_symlinks_run
assert_link Pictures Pictures

new_case c_locale
LANG=C.UTF-8
system_symlinks_run
assert_link Videos Videos

# Per-key fallback with a partial additional language pack.
cat >> "$test_dir/repo/modules/system/config/symlinks.conf" <<'BASH'
declare -A LINK_NAMES_de=([music]="Musik")
BASH
new_case partial
REM_MEDIA_LANG=de_DE.UTF-8
system_symlinks_run
assert_link Musik Music
assert_link Pictures Pictures

# A colon inside a target must not truncate the path.
cat >> "$test_dir/repo/modules/system/config/symlinks.conf" <<'BASH'
EXTRA_SYMLINKS+=("Downloads:$(storage_slow)/archive:2026")
BASH
new_case extra
LANG=en_US.UTF-8
system_symlinks_run
assert_link Downloads archive:2026

new_case empty_directory
LANG=en
mkdir "$TEST_HOME/Music"
system_symlinks_run
assert_link Music Music

new_case existing_directory
LANG=en
mkdir "$TEST_HOME/Music"
printf 'keep\n' > "$TEST_HOME/Music/document"
system_symlinks_run
[[ -f "$TEST_HOME/Music/document" && ! -L "$TEST_HOME/Music" ]]

new_case wrong_symlink
LANG=en
mkdir -p "$test_dir/other"
printf 'keep\n' > "$test_dir/other/document"
ln -s "$test_dir/other" "$TEST_HOME/Music"
if system_symlinks_run; then
    printf 'Expected conflicting symlink failure\n' >&2
    exit 1
fi
[[ -f "$test_dir/other/document" && -L "$TEST_HOME/Music" ]]

new_case broken_symlink
LANG=en
ln -s "$test_dir/missing" "$TEST_HOME/Music"
if system_symlinks_run; then exit 1; fi
[[ "$(readlink -- "$TEST_HOME/Music")" == "$test_dir/missing" ]]

new_case invalid_storage
SLOW_STORAGE=relative/path
if system_symlinks_run; then exit 1; fi

# Confirm a preloaded storage API is reused, including its own custom policy.
new_case preloaded
storage_slow() { printf '%s\n' "$SLOW_STORAGE/custom"; }
LANG=en
system_symlinks_run
[[ "$(readlink -- "$TEST_HOME/Music")" == "$SLOW_STORAGE/custom/Music" ]]

# Missing config must fail explicitly, without using stale arrays.
mv "$test_dir/repo/modules/system/config/symlinks.conf" "$test_dir/config.saved"
if system_symlinks_run; then exit 1; fi

printf 'PASS: 14 isolated scenarios (including repeated invocation)\n'
