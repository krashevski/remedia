#!/usr/bin/env bash
# modules/modules/home/snapshot/rsync.sh

set -euo pipefail
# set -x

rsync_safe() {
    local src="$1"
    local dst="$2"
    local base="${3:-}"

    mkdir -p "$dst"

    local RSYNC_OPTS=(
        -r
        -l
        -t
        -D
        --partial
        --ignore-errors
        --no-owner
        --no-group
        --no-perms
    )

    local EXCLUDES=(
        "--exclude=.cache/*"
        "--exclude=.local/share/Trash/*"
        "--exclude=snap/*"
        "--exclude=**/Cache/*"
        "--exclude=**/Code Cache/*"
        "--exclude=**/GPUCache/*"
        "--exclude=**/mesa_shader_cache/*"
    )

    set +e

    if [[ -n "$base" && -d "$base" ]]; then
        rsync "${RSYNC_OPTS[@]}" \
            "${EXCLUDES[@]}" \
            --compare-dest="$base" \
            "$src" "$dst"
    else
        rsync "${RSYNC_OPTS[@]}" \
            "${EXCLUDES[@]}" \
            "$src" "$dst"
    fi

    local rc=$?
    set -e

    return 0
}
