#!/usr/bin/env bash
# core/user_context.sh

init_user_context() {
    export RUN_USER="${USER:-unknown}"

    local detected_home=""
    detected_home="$(getent passwd "$RUN_USER" | cut -d: -f6 || true)"

    # fallback логика
    if [[ -z "$detected_home" ]]; then
        detected_home="${HOME:-}"
    fi

    # защита от критических значений
    if [[ -z "$detected_home" || "$detected_home" == "/" ]]; then
        echo "[WARN] invalid HOME detected → fallback to /tmp/$RUN_USER"
        detected_home="/tmp/$RUN_USER"
    fi

    export HOME="$detected_home"

    ensure_dir "$HOME"
   
    if [[ "${REMEDIA_QUIET:-0}" -eq 0 ]]; then
        echo "[USER_CTX] RUN_USER=$RUN_USER"
    fi

    if [[ "${REMEDIA_QUIET:-0}" -eq 0 ]]; then
        echo "[USER_CTX] HOME=$HOME"
    fi    
}

# --- resolvers ---
resolve_target_home() {
    local target_home

    if [[ -n "${USER_HOME:-}" ]]; then
        target_home="$USER_HOME"

    elif [[ -n "${SUDO_USER:-}" ]]; then
        target_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

    else
        target_home="$HOME"
    fi

    if [[ -z "$target_home" || "$target_home" == "/" ]]; then
        error invalid_home "$target_home"
        return 1
    fi

    printf '%s\n' "$target_home"
}
