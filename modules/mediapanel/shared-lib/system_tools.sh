#!/usr/bin/env bash
# modules/mediapanel/shared-lib/system_tools.sh

set -euo pipefail

has_flatpak() {
    local pkg="$1"
    command -v flatpak >/dev/null 2>&1 || return 1
    flatpak list --app | grep -q "$pkg"
}
