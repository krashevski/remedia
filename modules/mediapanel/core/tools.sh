#!/usr/bin/env bash
# mediapanel/core/tools.sh = pure logic

# =========================
# PROJECT UTILITIES
# =========================

set_active_project_safe() {
    local name="$1"

    if [[ ! -d "$PROJECT_DIR/$name" ]]; then
        echo "$(t MP_API_ERROR_PROJECT_NOT_FOUND)"
        return 1
    fi

    state_set "active_project" "$name"
    echo "$(t MP_API_OK_ACTIVE_PROJECT "$name")"
}
