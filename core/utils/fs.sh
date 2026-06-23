#!/usr/bin/env bash
# core/utils/fs.sh

set -euo pipefail

safe_du() {
    local path="${1:-}"

    [[ -z "$path" ]] && { echo "N/A"; return 0; }
    [[ ! -e "$path" ]] && { echo "N/A"; return 0; }

    local size
    size=$(du -sh -- "$path" 2>/dev/null | cut -f1) || true

    echo "${size:-N/A}"
}
