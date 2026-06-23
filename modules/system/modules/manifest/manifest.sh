#!/usr/bin/env bash
# modules/system/modules/manifest/manifest.sh 

system_manifest_generate() {
    local src="${1:-}"
    local out="${2:-}"
    
    [[ -n "$src" ]] || {
        echo "Remedia System Manifest module"
        echo
        echo "[MANIFEST] [GENERATE] missing src directory"
        echo
        echo "Usage:"
        echo "  remedia system manifest generate <directory>"
        return 1
    }

    local workers="${DOCTOR_WORKERS:-$(nproc 2>/dev/null || echo 4)}"

    if [[ -z "$out" ]]; then
        local name
        name="$(basename "$src")"
        out="$SYSTEM_VAR/${name}.manifest"
    fi

    mkdir -p "$(dirname "$out")"

    local tmp
    tmp="$(mktemp)"

    (
        cd "$src" || exit 1

        find . -type f -print0 |
        xargs -0 -n 1 -P "$workers" sha256sum |
        awk '{gsub(/^\.\//,"",$2); print $1 "  " $2}' |
        LC_ALL=C sort
    ) > "$tmp"

    mv "$tmp" "$out"

    echo "[MANIFEST] created: $out"

    # 🔥 REGISTER IN REGISTRY
    system_manifest_register "$src" "$out"
}

system_manifest_register() {
    local src="${1:-}"

    local manifest="$2"
    local registry="$SYSTEM_VAR/registry.db"

    mkdir -p "$SYSTEM_VAR"

    # remove old entry if exists
    grep -v "^$src|" "$registry" 2>/dev/null > "$registry.tmp" || true

    # add new entry
    echo "$src|$manifest|$(date +%s)" >> "$registry.tmp"

    mv "$registry.tmp" "$registry"

    echo "[REGISTRY] updated: $src"
}

system_manifests_list() {
    local src="${1:-}"
    local registry="${SYSTEM_VAR}/registry.db"

    [[ -f "$registry" ]] || {
        echo "[MANIFEST] registry not found"
        return 1
    }

    echo "[MANIFESTS]"

    while IFS='|' read -r s m t; do
        if [[ -n "$src" && "$s" != "$src" ]]; then
            continue
        fi

        echo "SRC : $s"
        echo "MAN : $m"
        echo "TS  : $t"
        echo "---------------------"
    done < "$registry"
}
