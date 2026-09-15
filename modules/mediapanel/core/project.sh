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

    [[ -n "${TRASH_DIR:-}" && "$TRASH_DIR" != "/" ]] || {
        echo "[ERROR] invalid TRASH_DIR: ${TRASH_DIR:-empty}"
        return 1
    }

    [[ -d "$TRASH_DIR" ]] || {
        echo "[INFO] trash empty"
        return 0
    }

    local fast_root
    fast_root="$(storage_fast)" || {
        echo "[ERROR] cannot determine FAST storage"
        return 1
    }

    [[ -n "$fast_root" && "$fast_root" != "/" ]] || {
        echo "[ERROR] invalid FAST storage path: $fast_root"
        return 1
    }

    local trash_item
    local trash_name
    local project
    local fast_project_dir
    local found=0

    echo "[PURGE] TRASH_DIR: $TRASH_DIR"
    echo "[PURGE] FAST root: $fast_root"

    while IFS= read -r -d '' trash_item; do
        found=1
        
        trash_name="${trash_item##*/}"

        # DELETE сохраняет проект как:
        # <исходное_имя>_<10-значный Unix timestamp>
        if [[ "$trash_name" =~ ^(.+)_([0-9]{10})$ ]]; then
            project="${BASH_REMATCH[1]}"
        else
            project="$trash_name"
        fi
        
        fast_project_dir="$fast_root/projects/$project"

        echo
        echo "[PURGE] trash entry: $trash_name"
        echo "[PURGE] original project: $project"
        echo "[PURGE] project trash: $trash_item"
        echo "[PURGE] project proxy: $fast_project_dir/proxy"
    
        # Защита от ошибочного пути.
        case "$fast_project_dir" in
            "$fast_root"/projects/*)
                ;;
            *)
                echo "[ERROR] unsafe proxy path: $fast_project_dir"
                return 1
                ;;
        esac

        if [[ -e "$fast_project_dir" ]]; then
            echo "[PURGE] removing FAST project data: $fast_project_dir"

            rm -rf -- "$fast_project_dir" || {
                echo "[ERROR] cannot remove: $fast_project_dir"
                return 1
            }

        else
            echo "[INFO] FAST project data not found: $fast_project_dir"
        fi

        echo "[PURGE] removing project from trash: $trash_item"

        rm -rf -- "$trash_item" || {
            echo "[ERROR] cannot remove: $trash_item"
            return 1
        }

    done < <(
        find "$TRASH_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -print0
    )

    if (( found == 0 )); then
        echo "[INFO] trash empty"
        return 0
    fi

    echo
    echo "[OK] trash and project proxies purged"
}

