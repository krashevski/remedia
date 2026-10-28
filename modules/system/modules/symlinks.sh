#!/usr/bin/env bash
# modules/system/modules/symlinks.sh
# Requires Bash >= 4.3 (associative arrays and namerefs).
# The Remedia launcher loads core/config.sh and calls load_config() once.

# Resolve paths when sourced, so a later cd does not affect config loading.
REMEDIA_SYMLINKS_MODULE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || return 1

cmd_symlinks_run() {
    system_symlinks_run "$@"
}

system_symlinks_run() {
    info "Symlinks: start"

    # Reuse an already loaded core; otherwise load only storage defaults.
    # Do not reload global configuration from a leaf module.
    if ! declare -F storage_slow >/dev/null; then
        local storage_file="$REMEDIA_SYMLINKS_MODULE_DIR/../../../core/storage.sh"
        if [[ ! -r "$storage_file" ]]; then
            warn "Storage API unavailable: $storage_file"
            return 1
        fi
        # shellcheck disable=SC1090
        source "$storage_file" || return 1
    fi

    local BASE_DIR TARGET_HOME
    BASE_DIR="$(storage_slow)" || return 1
    TARGET_HOME="$(resolve_target_home)" || return 1
    if [[ "$BASE_DIR" != /* || "$TARGET_HOME" != /* ]]; then
        warn "Storage and home paths must be absolute"
        return 1
    fi

    local config_file="$REMEDIA_SYMLINKS_MODULE_DIR/../config/symlinks.conf"
    if [[ ! -r "$config_file" ]]; then
        warn "Symlinks config unavailable: $config_file"
        return 1
    fi

    # Keep configuration local to this invocation, including repeated runs.
    local -A TARGET_DIRS=() LINK_NAMES_en=()
    local -a EXTRA_SYMLINKS=()
    # shellcheck disable=SC1090
    source "$config_file" || return 1

    # A locale can look like ru_RU.UTF-8, ja-JP, en.UTF-8 or C.UTF-8.
    local lang="${REM_MEDIA_LANG:-${LANG:-en}}"
    lang="${lang,,}"
    lang="${lang%%[_.@-]*}"
    # Validate before using a language as part of a variable name.
    [[ "$lang" =~ ^[a-z]+$ ]] || lang=en

    local names_ref="LINK_NAMES_${lang}" declaration
    declaration="$(declare -p "$names_ref" 2>/dev/null)" || declaration=""
    if [[ "$declaration" != "declare -A "* ]]; then
        names_ref=LINK_NAMES_en
    fi
    local -n LINK_NAMES="$names_ref"

    local key relative target link_name link_path pair name
    for key in "${!TARGET_DIRS[@]}"; do
        relative="${TARGET_DIRS[$key]}"
        if [[ -z "$relative" || "$relative" == /* || "/$relative/" == */../* || "/$relative/" == */./* ]]; then
            warn "Invalid relative target for key: $key"
            return 1
        fi
        link_name="$(get_link_name "$key" LINK_NAMES LINK_NAMES_en)" || return 1
        system_symlinks_valid_name "$link_name" || return 1
    done

    # Validate all extra entries before creating anything.
    for pair in "${EXTRA_SYMLINKS[@]}"; do
        name="${pair%%:*}"
        target="${pair#*:}"
        if [[ "$pair" != *:* || "$target" != /* ]]; then
            warn "Invalid symlink format: $pair"
            return 1
        fi
        system_symlinks_valid_name "$name" || return 1
    done

    for key in "${!TARGET_DIRS[@]}"; do
        target="${BASE_DIR%/}/${TARGET_DIRS[$key]}"
        link_name="$(get_link_name "$key" LINK_NAMES LINK_NAMES_en)" || return 1
        link_path="${TARGET_HOME%/}/$link_name"
        ensure_dir "$target" || return 1
        ensure_symlink "$link_path" "$target" || return 1
    done

    for pair in "${EXTRA_SYMLINKS[@]}"; do
        name="${pair%%:*}"
        target="${pair#*:}"
        link_path="${TARGET_HOME%/}/$name"
        ensure_dir "$target" || return 1
        ensure_symlink "$link_path" "$target" || return 1
    done

    info "Symlinks: done"
}

system_symlinks_valid_name() {
    local name="$1"
    if [[ -z "$name" || "$name" == . || "$name" == .. || "$name" == */* ]]; then
        warn "Invalid symlink name: $name"
        return 1
    fi
}

get_link_name() {
    local key="$1"
    local -n primary="$2"
    local -n fallback="$3"
    local value="${primary[$key]:-${fallback[$key]:-}}"
    if [[ -z "$value" ]]; then
        warn "Missing English link name for key: $key"
        return 1
    fi
    printf '%s\n' "$value"
}

ensure_dir() {
    [[ -d "$1" ]] || mkdir -p -- "$1"
}

ensure_symlink() {
    local link="${1:?missing link}"
    local target="${2:?missing target}"

    # Check symlinks BEFORE directories: never inspect/remove their contents.
    if [[ -L "$link" ]]; then
        if [[ "$(realpath -m -- "$link")" == "$(realpath -m -- "$target")" ]]; then
            info "skip (ok): $link"
        else
            warn "conflicting symlink: $link"
            return 1
        fi
        return 0
    fi

    if [[ -d "$link" ]]; then
        # rmdir succeeds only for an empty real directory.
        if rmdir -- "$link" 2>/dev/null; then
            :
        elif ui_confirm_policy "ask" "Replace directory $link?"; then
            rm -rf -- "$link" || return 1
        else
            warn "skip: $link"
            return 0
        fi
    elif [[ -e "$link" ]]; then
        warn "conflict: $link"
        return 1
    fi

    ln -s -- "$target" "$link" || return 1
    info "linked: $link → $target"
}

# Logging fallbacks: preserve the launcher's existing functions.
if ! declare -F info >/dev/null; then
    info() { printf '[INFO] %s\n' "$*"; }
fi
if ! declare -F warn >/dev/null; then
    warn() { printf '[WARN] %s\n' "$*" >&2; }
fi
