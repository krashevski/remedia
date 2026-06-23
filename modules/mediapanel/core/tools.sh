#!/usr/bin/env bash
# mediapanel/core/tools.sh = pure logic

# =========================
# PROJECT UTILITIES
# =========================

set_active_project_safe() {
    local name="$1"

    if [[ ! -d "$PROJECT_DIR/$name" ]]; then
        echo "[ERROR] project not found"
        return 1
    fi

    state_set "active_project" "$name"
    echo "[OK] active project: $name"
}
