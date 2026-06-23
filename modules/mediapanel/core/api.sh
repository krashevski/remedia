#!/usr/bin/env bash
# modules/mediapanel/api.sh

# =========================
# PROJECT API (UI SAFE LAYER)
# =========================

project_create() {
    local project_name
    project_name="$(project_core_create "$@")" || return 1

    echo "[OK] project created: $project_name"
}

project_list() {
    project_list_raw "$@"
}

delete_project() {
    project_core_delete "$@"
}

set_active_project() {
    local name="$1"

    if ! project_exists "$name"; then
        echo "[ERROR] project not found"
        return 1
    fi

    state_save "active_project" "$name"
    echo "[OK] active project: $name"
}

get_active_project() {
    state_init
    state_get "active_project"
}

activate_project_full() {
    local name="$1"

    set_active_project "$name" || return 1
    pipeline_init "$name"

    echo "[OK] project ready for pipeline: $name"
}

project_restore() {
    local name

    name="$(project_core_restore "$1")" || return 1

    echo -e "${GREEN}[RESTORE]${RESET} $name"

    if ! set_active_project "$name"; then
        echo -e "${RED}[ERROR] failed to activate project${RESET}"
        return 1
    fi

    pipeline_init "$name"
    echo -e "${CYAN}[PIPELINE] initialized${RESET}"
}
