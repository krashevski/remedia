#!/usr/bin/env bash
# core/guard.sh

require_non_empty() {
    local val="${1:-}"
    local name="${2:-value}"

    if [[ -z "$val" ]]; then
        echo "[REMEDIA] empty $name"
        exit 1
    fi
}

require_file() {
    [[ -f "$1" ]] || {
        echo "[REMEDIA] missing file: $1"
        exit 1
    }
}
