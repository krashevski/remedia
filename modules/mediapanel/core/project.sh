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
        echo "$(t MP_UI_INFO_TRASH_EMPTY)"
        return 0
    }

    echo "$(t MP_PROJECT_TRASH)"

    local i=1
    while IFS= read -r dir; do
        echo "$i) $dir"
        ((i++))
    done < <(find "$TRASH_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
}

purge_trash_core() {

    [[ -n "${TRASH_DIR:-}" && "$TRASH_DIR" != "/" ]] || {
        echo "$(t MP_PROJECT_ERROR_INVALID_TRASH_DIR "${TRASH_DIR:-empty}")"
        return 1
    }

    [[ -d "$TRASH_DIR" ]] || {
        echo "$(t MP_UI_INFO_TRASH_EMPTY)"
        return 0
    }

    local fast_root
    fast_root="$(storage_fast)" || {
        echo "$(t MP_PROJECT_ERROR_CANNOT_DETERMINE_FAST_STORAGE)"
        return 1
    }

    [[ -n "$fast_root" && "$fast_root" != "/" ]] || {
        echo "$(t MP_PROJECT_ERROR_INVALID_FAST_STORAGE_PATH "$fast_root")"
        return 1
    }

    local trash_item
    local trash_name
    local project
    local fast_project_dir
    local found=0

    echo "$(t MP_PROJECT_PURGE_TRASH_DIR "$TRASH_DIR")"
    echo "$(t MP_PROJECT_PURGE_FAST_ROOT "$fast_root")"

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
        echo "$(t MP_PROJECT_PURGE_TRASH_ENTRY "$trash_name")"
        echo "$(t MP_PROJECT_PURGE_ORIGINAL_PROJECT "$project")"
        echo "$(t MP_PROJECT_PURGE_PROJECT_TRASH "$trash_item")"
        echo "$(t MP_PROJECT_PURGE_PROJECT_PROXY_PROXY "$fast_project_dir")"
    
        # Защита от ошибочного пути.
        case "$fast_project_dir" in
            "$fast_root"/projects/*)
                ;;
            *)
                echo "$(t MP_PROJECT_ERROR_UNSAFE_PROXY_PATH "$fast_project_dir")"
                return 1
                ;;
        esac

        if [[ -e "$fast_project_dir" ]]; then
            echo "$(t MP_PROJECT_PURGE_REMOVING_FAST_PROJECT_DATA "$fast_project_dir")"

            rm -rf -- "$fast_project_dir" || {
                echo "$(t MP_PROJECT_ERROR_CANNOT_REMOVE "$fast_project_dir")"
                return 1
            }

        else
            echo "$(t MP_PROJECT_INFO_FAST_PROJECT_DATA_NOT_FOUND "$fast_project_dir")"
        fi

        echo "$(t MP_PROJECT_PURGE_REMOVING_PROJECT_FROM_TRASH "$trash_item")"

        rm -rf -- "$trash_item" || {
            echo "$(t MP_PROJECT_ERROR_CANNOT_REMOVE "$trash_item")"
            return 1
        }

    done < <(
        find "$TRASH_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -print0
    )

    if (( found == 0 )); then
        echo "$(t MP_UI_INFO_TRASH_EMPTY)"
        return 0
    fi

    echo
    echo "$(t MP_PROJECT_OK_TRASH_AND_PROJECT_PROXIES_PURGED)"
}

