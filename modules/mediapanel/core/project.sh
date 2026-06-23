#!/usr/bin/env bash
# modules/mediapanel/core/project.sh

project_list() {

    local JSON="${CLI_JSON:-0}"

    mapfile -t projects < <(
        find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
        sort -t '_' -k1,1n
    )

    if (( ${#projects[@]} == 0 )); then
        [[ "$JSON" == "1" ]] && echo "[]" || true
        return
    fi

    if (( JSON == 1 )); then
        printf "[\n"
        for i in "${!projects[@]}"; do
            if (( i == ${#projects[@]} - 1 )); then
                printf '  "%s"\n' "${projects[$i]}"
            else
                printf '  "%s",\n' "${projects[$i]}"
            fi
        done
        printf "]\n"
        return
    fi

    for p in "${projects[@]}"; do
        echo "  $p"
    done
}

trash_list() {
    [[ -d "$TRASH_DIR" ]] || {
        echo "[INFO] trash empty"
        return 0
    }

    echo "=== TRASH ==="

    local i=1
    while IFS= read -r dir; do
        echo "$i) $dir"
        ((i++))
    done < <(find "$TRASH_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
}

purge_trash_core() {
    rm -rf "$TRASH_DIR"/* 2>/dev/null || true
}


