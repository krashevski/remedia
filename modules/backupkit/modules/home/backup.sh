#!/usr/bin/env bash
# modules/backupkit/modules/home/backup.sh

verify_graph() {
    local id="$1"
    local visited
    visited="$(mktemp)"
    
    echo "[VERIFY] starting"

    local node
    while read -r node; do
        if [[ ! -f "$SNAPSHOT_ROOT/$node/meta.json" ]]; then
            echo "[BROKEN] missing meta: $node"
            rm -f "$visited"
            return 1
        fi
    done < <(walk_graph "$id" "$visited")

    rm -f "$visited"
    echo "[VERIFY] OK"
}

get_snapshot_base() {
    local id="$1"

    jq -r '.base // empty' \
        "$SNAPSHOT_ROOT/$id/meta.json"
}

get_parent() {
    jq -r '.parents[0] // empty' "$SNAPSHOT_ROOT/$1/meta.json"
}

get_parents() {
    jq -r '.parents[]? // empty' "$SNAPSHOT_ROOT/$1/meta.json"
}

get_depth() {
    jq -r '.depth // 1' "$SNAPSHOT_ROOT/$1/meta.json"
}

walk_graph() {
    local id="$1"
    local visited="$2"

    [[ -z "$id" ]] && return 0

    if grep -qx "$id" "$visited" 2>/dev/null; then
        return 0
    fi

    echo "$id" >> "$visited"
    echo "$id"

    local p
    while read -r p; do
        walk_graph "$p" "$visited"
    done < <(get_parents "$id")
}

is_root() {
    [[ "$(jq -r '.type' "$SNAPSHOT_ROOT/$1/meta.json")" == "full" ]]
}

build_graph_index() {
    mkdir -p "$STATE_DIR"

    shopt -s nullglob
    local files=("$SNAPSHOT_ROOT"/*/meta.json)
    shopt -u nullglob

    if (( ${#files[@]} == 0 )); then
        echo "[]" > "$STATE_DIR/graph.json"
        return 0
    fi

    jq -s 'map({id,type,parents})' "${files[@]}" \
        > "$STATE_DIR/graph.json" || echo "[]" > "$STATE_DIR/graph.json"
}

write_meta() {
    local id="$1"
    local root="$2"
    local type="$3"
    local depth="$4"
    shift 4
    local parents=("$@")

    local parents_json

    if (( ${#parents[@]} == 0 )) || [[ -z "${parents[0]:-}" ]]; then
        parents_json="[]"
    else
        parents_json="$(printf '%s\n' "${parents[@]}" | jq -R . | jq -s .)"
    fi

    jq -n \
        --arg id "$id" \
        --arg type "$type" \
        --argjson depth "$depth" \
        --argjson parents "$parents_json" \
        --argjson ts "$(date +%s)" '
        {
            id: $id,
            type: $type,
            parents: $parents,
            depth: $depth,
            timestamp: $ts
        }
    ' > "$root/meta.json"
}

snapshot_lock_acquire() {
    mkdir -p "$STATE_DIR"

    exec 9>"$STATE_DIR/.lock"

    if ! flock -n 9; then
        echo "[LOCK] backup already running"
        return 1
    fi

    echo "$1" > "$STATE_DIR/.building"
}

snapshot_lock_release() {
    rm -f "$STATE_DIR/.building"
    exec 9>&-
}

create_full_snapshot() {
    local id="$1"
    local root="$SNAPSHOT_ROOT/$id"
    local depth=1

    mkdir -p "$root/snapshot"

    rsync_safe "$HOME/" "$root/snapshot"

    write_meta "$id" "$root" "full" "$depth"
}

create_diff_snapshot_safe() {
    local id="$1"
    local parent="$2"
    local root="$SNAPSHOT_ROOT/$id"
    parent_depth="$(get_depth "$parent")"
    depth=$((parent_depth + 1))

    mkdir -p "$root/snapshot"

    # guard 1: self parent
    if [[ "$parent" == "$id" ]]; then
        parent=""
    fi

    # guard 2: validate parent
    if [[ -z "$parent" ]]; then
        rsync_safe "$HOME/" "$root/snapshot"
        write_meta "$id" "$root" "full"
        return 0
    fi

    local base="$SNAPSHOT_ROOT/$parent/snapshot"

    # guard 3: base integrity
    if [[ ! -d "$base" ]]; then
        rsync_safe "$HOME/" "$root/snapshot"
        write_meta "$id" "$root" "full"
        return 0
    fi

    rsync_safe "$HOME/" "$root/snapshot" "$base"
    write_meta "$id" "$root" "diff" "$depth" "$parent"
}

create_compact_snapshot() {
    local id="$1"
    local parent="$2"
    local root="$SNAPSHOT_ROOT/$id"

    mkdir -p "$root/snapshot"

    # build full state from current system
    rsync_safe "$HOME/" "$root/snapshot"

    # mark as new base snapshot
    # 2. BUT:
    # - не просто full
    # - а “новый root”
    # - сброс цепочки
    write_meta "$id" "$root" "full" 1
}

find_latest_snapshot() {
    shopt -s nullglob

    local dirs=("$SNAPSHOT_ROOT"/*/)
    shopt -u nullglob

    local latest=""

    for d in "${dirs[@]}"; do
        d="${d%/}"
        local name="${d##*/}"

        # 1. фильтр формата snapshot
        [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$ ]] || continue

        # 2. проверка целостности
        [[ -f "$d/meta.json" ]] || continue
        [[ -d "$d/snapshot" ]] || continue

        latest="$name"
    done

    echo "$latest"
}

select_latest_snapshot() {
    local best=""
    local best_ts=0

    for d in "$SNAPSHOT_ROOT"/*; do
        [[ -f "$d/meta.json" ]] || continue
        [[ -d "$d/snapshot" ]] || continue

        local id="${d##*/}"
        local ts
        ts=$(jq -r '.timestamp // 0' "$d/meta.json")

        # skip invalid
        [[ -z "$(jq -r '.parents[0] // empty' "$d/meta.json")" ]] && continue

        if (( ts > best_ts )); then
            best="$id"
            best_ts="$ts"
        fi
    done

    echo "$best"
}

find_latest_snapshot_safe() {
    local current="$1"

    local latest=""
    local d name

    shopt -s nullglob
    local dirs=("$SNAPSHOT_ROOT"/*/)
    shopt -u nullglob

    for d in "${dirs[@]}"; do
        d="${d%/}"
        name="${d##*/}"

        # 1. format check
        [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}$ ]] || continue

        # 2. integrity check (ZFS-like scrub gate)
        [[ -f "$d/meta.json" ]] || continue
        [[ -d "$d/snapshot" ]] || continue

        # 3. skip current build
        [[ "$name" == "$current" ]] && continue

        # 4. track latest
        latest="$name"
    done

    echo "$latest"
}

select_parent_snapshot() {
    local current="$1"

    local parent
    parent="$(find_latest_snapshot_safe "$current" || true)"

    # hard safety checks (Btrfs-style guards)

    [[ -z "$parent" ]] && return 1
    [[ "$parent" == "$current" ]] && return 1

    # integrity re-check
    [[ -f "$SNAPSHOT_ROOT/$parent/meta.json" ]] || return 1
    [[ -d "$SNAPSHOT_ROOT/$parent/snapshot" ]] || return 1

    echo "$parent"
}

find_safe_root() {
    local id
    id="$(select_latest_snapshot || true)"

    [[ -z "$id" ]] && return 1

    while [[ -n "$id" ]]; do
        [[ -f "$SNAPSHOT_ROOT/$id/meta.json" ]] || {
            id="$(get_parent "$id")"
            continue
        }

        [[ -d "$SNAPSHOT_ROOT/$id/snapshot" ]] || {
            id="$(get_parent "$id")"
            continue
        }

        if is_root "$id"; then
            echo "$id"
            return 0
        fi

        id="$(get_parent "$id")"
    done

    return 1
}

decide_mode_safe() {
    local parent="$1"

    [[ -z "$parent" ]] && { echo "full"; return; }
    [[ ! -d "$SNAPSHOT_ROOT/$parent/snapshot" ]] && { echo "full"; return; }
    [[ ! -f "$SNAPSHOT_ROOT/$parent/meta.json" ]] && { echo "full"; return; }

    local depth
    depth="$(get_depth "$parent")"

    # 🔥 1. COMPACTION FIRST (самый важный уровень)
    if (( depth >= 25 )); then
        echo "compact"
        return
    fi

    # 🔥 2. PERIODIC FULL SNAPSHOT (стабилизация цепи)
    if (( depth % 7 == 0 )); then
        echo "full"
        return
    fi

    # 🔥 3. NORMAL OPERATION
    echo "diff"
}
  
backupkit_backup() {
    echo "Backupkit Home module"
    echo

    local id
    id="$(date +"%Y-%m-%d_%H%M%S")"

    ensure_user_fs
    assert_user_owns_path "$USER_ROOT"

    self_heal_before_backup || true

    # 🔒 lock (ZFS transaction start)
    snapshot_lock_acquire "$id" || return 1

    # 🧠 parent selection (Btrfs-style)
    local parent
    parent="$(select_parent_snapshot "$id" || true)"

    if [[ "$parent" == "$id" ]]; then
        parent=""
    fi

    local mode
    mode="$(decide_mode_safe "$parent")"
    
    echo "[BACKUP] mode=$mode parent=$parent"

    if [[ "$mode" == "diff" ]]; then
        create_diff_snapshot_safe "$id" "$parent"
    elif [[ "$mode" == "compact" ]]; then
        create_compact_snapshot "$id" "$parent"
    else
        create_full_snapshot "$id"
    fi

    build_graph_index
    echo "$id" > "$STATE_DIR/.latest"

    # 🔓 unlock
    snapshot_lock_release
}

