#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

for lib in log.sh ui.sh; do
    if [[ ! -f "$ROOT_DIR/shared-lib/$lib" ]]; then
        echo "ERROR: Missing $lib in $ROOT_DIR/shared-lib/"
        exit 1
    fi
    source "$ROOT_DIR/shared-lib/$lib"
done

PROFILE_NAME="REBK"

log_info "=== Starting 10_create_profiles.sh ==="

# Получаем UUID профиля по имени, если уже существует
PROFILE_UUID=$(gsettings get org.gnome.Terminal.ProfilesList list | grep -o "'[^']*'" | head -n1)

# Создаём новый профиль
if ! gsettings get org.gnome.Terminal.ProfilesList list | grep -q "$PROFILE_NAME"; then
    UUID=$(uuidgen)
    gsettings set org.gnome.Terminal.ProfilesList list "$(gsettings get org.gnome.Terminal.ProfilesList list | sed "s/]$/, '$UUID']/")"
    gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/Terminal/Legacy/Profiles:/:$UUID/" visible-name "$PROFILE_NAME"
    log_info "Created new GNOME Terminal profile: $PROFILE_NAME ($UUID)"
else
    log_info "Profile $PROFILE_NAME already exists"
fi

log_info "=== Completed 10_create_profiles.sh ==="
