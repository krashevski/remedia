#!/usr/bin/env bash
# mediapanel/core/project_core.sh

# =========================
# NEXT PROJECT NUMBER
# =========================
next_project_number() {

    local max=0

    [[ -d "$PROJECT_DIR" ]] || {
        printf "%03d" 1
        return
    }

    while IFS= read -r -d '' dir; do
        name=$(basename "$dir")

        if [[ "$name" =~ ^([0-9]{3})_ ]]; then
            num=${BASH_REMATCH[1]}
            num=$((10#$num))

            (( num > max )) && max=$num
        fi

    done < <(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

    printf "%03d" $((max + 1))
}


# =========================
# PROJECT LIST
# =========================
project_list_raw() {
    mapfile -t projects < <(
        find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
        sort -t '_' -k1,1n
    )

    printf '%s\n' "${projects[@]}"
}

# =========================
# PROJECT PATHS
# =========================
project_paths() {
    local name="$1"
    printf '%s/%s\n' "$PROJECT_DIR" "$name"
}

# =========================
# PROJECT EXISTS
# =========================
project_exists() {
    [[ -d "$(project_paths "$1")" ]]
}

project_core_create() {

    local NAME="${CLI_NAME:-}"

    if [[ -z "$NAME" ]]; then
        if [[ "${CLI_NO_UI:-0}" == "1" ]]; then
            echo "[ERROR] name required"
            return 1
        fi
        read -r -p "Enter project name: " NAME
    fi

    NAME=$(printf "%s" "$NAME" | xargs)

    [[ -z "$NAME" ]] && {
        echo "[ERROR] empty name"
        return 1
    }

    local number
    number="$(next_project_number)"

    local project_name="${number}_${NAME}"
    local path="$PROJECT_DIR/$project_name"

    mkdir -p "$path"/{media,edit,scenes,audio,edit} || {
        echo "[ERROR] failed to create project dirs"
        return 1
    }

    echo "$project_name"
}

trash_list() {
    [[ -d "$TRASH_DIR" ]] || {
        echo "[INFO] trash empty"
        return 0
    }

    echo "=== TRASH ==="

    find "$TRASH_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort
}

project_core_delete() {

    local PROJECT="${CLI_PROJECT:-}"
    local YES="${CLI_YES:-0}"
    : "${STATE_DIR:?STATE_DIR not set}"

    [[ -z "$PROJECT" ]] && {
        echo "[ERROR] --project required"
        return 1
    }

    PROJECT="${PROJECT//\.\./}"
    PROJECT="$(printf "%s" "$PROJECT" | xargs)"

    local project_path="$PROJECT_DIR/$PROJECT"

    [[ ! -d "$project_path" ]] && {
        echo "[ERROR] project not found"
        return 1
    }

    # 🧠 clear active project if it is being deleted
    if [[ "$(get_active_project)" == "$PROJECT" ]]; then
        state_save "active_project" ""
        echo "[INFO] active project cleared"
    fi

    if [[ "${YES:-0}" != "1" ]]; then
        read -rp "Type DELETE to confirm: " confirm
        [[ "$confirm" != "DELETE" ]] && return
    fi

    mkdir -p "$TRASH_DIR"

    local ts
    ts=$(date +%s)

    mv "$project_path" "$TRASH_DIR/${PROJECT}_$ts"

    echo "[OK] moved to trash: $PROJECT"
}

project_core_restore() {
    local entry="${1:-}"

    [[ -z "$entry" ]] && {
        echo "[ERROR] no entry"
        return 1
    }

    local src="$TRASH_DIR/$entry"
    local name="${entry%_*}"

    [[ ! -d "$src" ]] && {
        echo "[ERROR] not found"
        return 1
    }

    local dest="$PROJECT_DIR/$name"

    mv "$src" "$dest"

    echo "$name"
}
