#!/usr/bin/env bash
# mediapanel/core/project_core.sh

# =========================
# NEXT PROJECT NUMBER
# =========================
next_project_number() {

    local max=0
    local name num

    [[ -d "$PROJECT_DIR" ]] || {
        printf "%03d" 1
        return
    }

    while IFS= read -r -d '' dir; do
        name=$(basename "$dir")

        if [[ "$name" =~ ^([0-9]{3})_ ]]; then
            num="${BASH_REMATCH[1]}"
            num=$((10#$num))

            (( num > max )) && max=$num
        fi

    done < <(
        find "$PROJECT_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -print0
    )

    printf "%03d" $((max + 1))
}


# =========================
# PROJECT LIST
# =========================
project_list_raw() {

    mapfile -t projects < <(
        find "$PROJECT_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%f\n' |
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

# =========================
# PROJECT CREATE
# =========================
project_core_create() {

    local NAME="${CLI_NAME:-}"

    if [[ -z "$NAME" ]]; then
        if [[ "${CLI_NO_UI:-0}" == "1" ]]; then
            echo "$(t MP_PROJECT_CORE_ERROR_NAME_REQUIRED)" >&2
            return 1
        fi

        read -r -p "$(t MP_PROJECT_CORE_ENTER_PROJECT_NAME)" NAME
    fi

    NAME=$(printf "%s" "$NAME" | xargs)

    [[ -z "$NAME" ]] && {
        echo "$(t MP_PROJECT_CORE_ERROR_EMPTY_NAME)" >&2
        return 1
    }

    local number
    number="$(next_project_number)"

    local project_name="${number}_${NAME}"
    local path="$PROJECT_DIR/$project_name"

    # --------------------------------------------------------
    # PROJECT DIRECTORIES
    # --------------------------------------------------------
        
    mkdir -p \
        "$path/media" \
        "$path/audio" \
        "$path/scenes" \
        "$path/edit" \
        "$path/short" \
        "$path/video" || {

        echo "$(t MP_PROJECT_CORE_ERROR_FAILED_TO_CREATE_PROJECT_DIRS)" >&2
        return 1
    }

    echo "$project_name"
}

# =========================
# TRASH LIST
# =========================
trash_list() {

    [[ -d "$TRASH_DIR" ]] || {
        echo "$(t MP_UI_INFO_TRASH_EMPTY)"
        return 0
    }

    echo "$(t MP_PROJECT_TRASH)"

    find "$TRASH_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf "%f\n" |
    sort
}


# =========================
# PROJECT DELETE
# =========================
project_core_delete() {

    local PROJECT="${CLI_PROJECT:-}"
    local YES="${CLI_YES:-0}"

    : "${STATE_DIR:?STATE_DIR not set}"

    [[ -z "$PROJECT" ]] && {
        echo "$(t MP_PROJECT_CORE_ERROR_PROJECT_REQUIRED)" >&2
        return 1
    }

    PROJECT="${PROJECT//\.\./}"
    PROJECT="$(printf "%s" "$PROJECT" | xargs)"

    local project_path="$PROJECT_DIR/$PROJECT"

    [[ ! -d "$project_path" ]] && {
        echo "$(t MP_API_ERROR_PROJECT_NOT_FOUND)"
        return 1
    }

    # --------------------------------------------------------
    # CLEAR ACTIVE PROJECT
    # --------------------------------------------------------

    if [[ "$(get_active_project)" == "$PROJECT" ]]; then
        state_save "active_project" ""
        echo "$(t MP_PROJECT_CORE_INFO_ACTIVE_PROJECT_CLEARED)"
    fi

    # --------------------------------------------------------
    # CONFIRM
    # --------------------------------------------------------

    if [[ "${YES:-0}" != "1" ]]; then
        read -rp "$(t MP_PROJECT_CORE_TYPE_DELETE_TO_CONFIRM)" confirm
        [[ "$confirm" != "DELETE" ]] && return
    fi

    mkdir -p "$TRASH_DIR"

    local ts
    ts=$(date +%s)

    mv "$project_path" "$TRASH_DIR/${PROJECT}_$ts"

    echo "$(t MP_PROJECT_CORE_OK_MOVED_TO_TRASH "$PROJECT")"
}


# =========================
# PROJECT RESTORE
# =========================
project_core_restore() {

    local entry="${1:-}"

    [[ -z "$entry" ]] && {
        echo "$(t MP_PROJECT_CORE_ERROR_NO_ENTRY)" >&2
        return 1
    }

    local src="$TRASH_DIR/$entry"
    local name="${entry%_*}"

    [[ ! -d "$src" ]] && {
        echo "$(t MP_PROJECT_CORE_ERROR_NOT_FOUND)" >&2
        return 1
    }

    local dest="$PROJECT_DIR/$name"

    mv "$src" "$dest"

    echo "$name"
}
