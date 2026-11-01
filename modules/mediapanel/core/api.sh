#!/usr/bin/env bash
# modules/mediapanel/api.sh

# =========================
# PROJECT API (UI SAFE LAYER)
# =========================

project_create() {
    local project_name
    project_name="$(project_core_create "$@")" || return 1

    echo "$(t MP_API_OK_PROJECT_CREATED "$project_name")"
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
        echo "$(t MP_API_ERROR_PROJECT_NOT_FOUND)"
        return 1
    fi

    state_save "active_project" "$name"
    echo "$(t MP_API_OK_ACTIVE_PROJECT "$name")"
}

get_active_project() {
    state_init
    state_get "active_project"
}

activate_project_full() {
    local name="$1"

    set_active_project "$name" || return 1
    pipeline_init "$name"

    echo "$(t MP_API_OK_PROJECT_READY_FOR_PIPELINE "$name")"
}

project_restore() {
    local name

    name="$(project_core_restore "$1")" || return 1

    echo -e "$(t MP_API_RESTORE "${GREEN}" "${RESET}" "$name")"

    if ! set_active_project "$name"; then
        echo -e "$(t MP_API_ERROR_FAILED_TO_ACTIVATE_PROJECT "${RED}" "${RESET}")"
        return 1
    fi

    pipeline_init "$name"
    echo -e "$(t MP_API_PIPELINE_INITIALIZED "${CYAN}" "${RESET}")"
}
