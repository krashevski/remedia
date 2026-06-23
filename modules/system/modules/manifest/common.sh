#!/usr/bin/env bash
# modules/system/modules/manifest/common.sh 

resolve_manifest_path() {
    local src="$1"

    local name
    name="$(basename "$(realpath "$src")")"

    local path="$SYSTEM_VAR/${name}.manifest"

    [[ -f "$path" ]] || {
        echo "[ERROR] manifest missing: $path"
        return 1
    }

    echo "$path"
}

get_manifest() {
    local src="${1:-}"
    local registry="${SYSTEM_VAR}/registry.db"

    [[ -f "$registry" ]] || return 1

    awk -F'|' -v s="$src" '$1 == s {print $2; exit}' "$registry" || true
}

auto_resolve_manifest() {
    manifest="$(get_manifest "$root" || true)"

    if [[ -z "$manifest" ]]; then
        echo "[ERROR] manifest not found for: $root"
        return 1
    fi
}           

