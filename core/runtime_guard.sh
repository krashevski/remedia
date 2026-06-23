#!/usr/bin/env bash
# core/runtime_guard.sh

set -euo pipefail

runtime_require() {
    local name="$1"
    local value="${!name:-}"

    if [[ -z "$value" ]]; then
        echo "[RUNTIME v3 FATAL] $name is empty"
        return 1
    fi
}

runtime_require_dir() {
    local name="$1"
    local value="${!name:-}"

    runtime_require "$name"

    mkdir -p "$value" || {
        echo "[RUNTIME v3 FATAL] cannot create $name=$value"
        return 1
    }
}

runtime_fatal() {
    echo "[RUNTIME v3 FATAL] $1" >&2
    exit 1
}

guard_runtime() {

    [[ -z "${HOME:-}" ]] && {
        echo "[WARN] HOME fallback /tmp"
        HOME="/tmp"
    }

    [[ -z "${USER:-}" ]] && {
        echo "[WARN] USER fallback unknown"
        USER="unknown"
    }

    [[ -z "${REMEDIA_ROOT:-}" ]] && \
        runtime_fatal "REMEDIA_ROOT missing"

    [[ -z "${CACHE_DIR:-}" ]] && \
        runtime_fatal "CACHE_DIR missing"

    export HOME USER REMEDIA_ROOT CACHE_DIR
}

runtime_require STATE_DIR
runtime_require STATE_FILE
