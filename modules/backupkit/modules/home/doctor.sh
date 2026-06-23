#!/usr/bin/env bash
# modules/backupkit/modules/home/doctor.sh

validate_graph_node() {
    local id="$1"

    [[ -f "$SNAPSHOT_ROOT/$id/meta.json" ]] || return 1
    [[ -d "$SNAPSHOT_ROOT/$id/snapshot" ]] || return 1
}

validate_chain() {
    local id="$1"

    while [[ -n "$id" ]]; do
        [[ ! -f "$SNAPSHOT_ROOT/$id/meta.json" ]] && {
            echo "[CHAIN BROKEN] $id"
            return 1
        }
        id="$(get_parent "$id")"
        ((depth++))
    done
}

compute_depth() {
    local id="$1"
    local depth=0

    while [[ -n "$id" ]]; do
        ((depth++))
        id="$(get_parent "$id")"
    done

    echo "$depth"
}

backupkit_doctor() {
    echo "Backupkit Home module"
    echo
    log_debug "[DEBUG] doctor called from:"
    print_stack_trace
    set +e
    local base="$SNAPSHOT_ROOT"

    echo "[DOCTOR] scanning graph..."
    
    local total=0
    local full_count=0
    local diff_count=0

    shopt -s nullglob
    local dirs=("$SNAPSHOT_ROOT"/*)
    shopt -u nullglob

    for d in "${dirs[@]}"; do
        [[ -d "$d" ]] || continue
        local id="${d##*/}"

        if [[ -f "$d/meta.json" ]]; then
            ((total++))

            local type
            type="$(jq -r '.type' "$d/meta.json" 2>/dev/null || echo "" 2>/dev/null || echo "")"

            if [[ "$type" == "full" ]]; then
                ((full_count++))
            elif [[ "$type" == "diff" ]]; then
                ((diff_count++))
            fi
        fi
    done

    echo "[DOCTOR] stats:"
    echo "  total_snapshots=$total"
    echo "  full=$full_count"
    echo "  diff=$diff_count"
    
    if (( full_count > diff_count )); then
        echo "[WARN] too many full snapshots → inefficient storage"
    fi

    # 👇 ВСТАВЛЯЕМ СЮДА
    if [[ -f "$STATE_DIR/.latest" ]]; then
        local latest
        latest="$(cat "$STATE_DIR/.latest")"

        if [[ ! -f "$SNAPSHOT_ROOT/$latest/meta.json" ]]; then
            echo "[WARN] .latest broken → $latest"
        else
            echo "[INFO] latest → $latest"
        fi
        else
        echo "[WARN] .latest missing"
    fi

    local broken=0
    local missing_meta=0
    local missing_snapshot=0
    local orphans=0

    shopt -s nullglob
    local nodes=("$base"/*)
    shopt -u nullglob

    if (( ${#nodes[@]} == 0 )); then
        echo "[DOCTOR] empty snapshot store"
        return 0
    fi
    
    local head
    head="$(select_latest_snapshot || find_latest_snapshot || true)"

    if [[ -n "$head" ]]; then
        local depth
        depth="$(compute_depth "$head")"

        log_debug "[DEBUG] latest_fs=$(find_latest_snapshot)"
        log_debug "[DEBUG] head_graph=$(select_latest_snapshot)"
        echo "[DOCTOR] head=$head"
        echo "[DOCTOR] chain depth=$depth"
    fi

    local root
    root="$(find_safe_root || true)"

    [[ -n "$root" ]] && echo "[INFO] root → $root"

    local n id

    for n in "${nodes[@]}"; do
        id="$(basename "$n")"

        [[ ! -d "$n" ]] && continue

        if [[ ! -f "$n/meta.json" ]]; then
            echo "[BROKEN] missing meta: $id"
            ((missing_meta++))
        fi

        if [[ ! -d "$n/snapshot" ]]; then
            echo "[BROKEN] missing snapshot: $id"
            ((missing_snapshot++))
        fi
    done

    # orphan detection (no graph reference)
    if command -v jq >/dev/null 2>&1 && [[ -f "$STATE_DIR/graph.json" ]]; then
        local referenced
        referenced="$(mktemp)"

        jq -r '.[].id' "$STATE_DIR/graph.json" 2>/dev/null > "$referenced" || true

        for n in "${nodes[@]}"; do
            id="$(basename "$n")"
            if ! grep -qx "$id" "$referenced" 2>/dev/null; then
                echo "[ORPHAN] $id"
                ((orphans++))
            fi
        done

        rm -f "$referenced"
    fi
    
    local broken_parents=0

    for d in "${dirs[@]}"; do
        [[ -f "$d/meta.json" ]] || continue
        local id="${d##*/}"

        mapfile -t parents < <(jq -r '.parents[]?' "$d/meta.json" 2>/dev/null || true)

        for p in "${parents[@]}"; do
            [[ -z "$p" ]] && continue

            if [[ ! -f "$SNAPSHOT_ROOT/$p/meta.json" ]]; then
                echo "[BROKEN] missing parent: $id → $p"
                ((broken_parents++))
            fi
        done
    done
    
    local orphan_diff=0

    for d in "${dirs[@]}"; do
        [[ -f "$d/meta.json" ]] || continue

        local id="${d##*/}"
        local type
        type="$(jq -r '.type' "$d/meta.json" 2>/dev/null || echo "")"

        if [[ "$type" == "diff" ]]; then
            local parent
            parent="$(jq -r '.parents[0] // empty' "$d/meta.json")"

            if [[ -z "$parent" ]]; then
                echo "[BROKEN] diff without parent: $id"
                ((orphan_diff++))
            fi
        fi
    done
    
    local head
    head="$(select_latest_snapshot || true)"

    if [[ -n "$head" ]]; then
        local depth
        depth="$(compute_depth "$head")"

        echo "[DOCTOR] head depth=$depth"

        if (( depth > 50 )); then
            echo "[WARN] chain too long → recommend full snapshot"
        fi
    fi

    echo "[DOCTOR] summary:"
    echo "  missing_meta=$missing_meta"
    echo "  missing_snapshot=$missing_snapshot"
    echo "  broken_parents=$broken_parents"
    echo "  orphan_diff=$orphan_diff"
    
    local issues=$((missing_meta + missing_snapshot + broken_parents + orphan_diff))

    if (( issues == 0 )); then
        echo "[DOCTOR] health=100%"
    else
        echo "[DOCTOR] health=$((100 - issues * 10))%"
    fi

    if (( missing_meta + missing_snapshot + orphans == 0 )); then
        echo "[DOCTOR] OK"
        return 0
    fi

    echo "[DOCTOR] issues detected"
    return 1
    set -e
}

self_heal_before_backup() {
    backupkit_doctor >/dev/null 2>&1 || true

    local latest
    latest="$(find_latest_snapshot || true)"

    echo "$latest"
}


