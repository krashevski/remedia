#!/usr/bin/env bash
# modules/backupkit/modules/home/removal.sh

backupkit_gc() {
    echo "Backupkit Home module"
    echo
    local keep_full="${1:-2}"

    echo "[GC] start..."

    local latest
    latest="$(find_latest_snapshot)"

    [[ -z "$latest" ]] && {
        echo "[GC] no snapshots"
        return 0
    }

    echo "[GC] latest: $latest"

    ########################################
    # 1. сохранить цепочку latest
    ########################################

    local visited
    visited="$(mktemp)"

    walk_graph "$latest" "$visited" >/dev/null

    ########################################
    # 2. найти full snapshots
    ########################################

    local fulls=()

    for d in "$SNAPSHOT_ROOT"/*; do
        [[ -f "$d/meta.json" ]] || continue
        
        assert_user_owns_path "$d"

        local id="${d##*/}"
        if is_root "$id"; then
            fulls+=("$id")
        fi
    done

    # сортируем (старые → новые)
    IFS=$'\n' fulls=($(sort <<<"${fulls[*]}"))
    unset IFS

    ########################################
    # 3. оставить последние N full
    ########################################

    local keep=()

    local count="${#fulls[@]}"
    local start=$(( count > keep_full ? count - keep_full : 0 ))

    for ((i=start; i<count; i++)); do
        keep+=("${fulls[$i]}")
    done

    ########################################
    # 4. удаление
    ########################################

    shopt -s nullglob

    for d in "$SNAPSHOT_ROOT"/*; do
        [[ -d "$d" ]] || continue

        local id="${d##*/}"

        # skip latest chain
        if grep -qx "$id" "$visited"; then
            continue
        fi

        # skip protected fulls
        if printf '%s\n' "${keep[@]}" | grep -qx "$id"; then
            continue
        fi

        echo "[GC] removing $id"
        rm -rf "$d"
    done

    shopt -u nullglob

    rm -f "$visited"

    echo "[GC] done"
}
