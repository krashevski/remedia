#!/bin/bash
# 10_create_profiles.sh

set -euo pipefail

: "${MODULE_ROOT:?}"
: "${SHARED_DIR:?}"
: "${MODULE_ROOT:?}"
source "$SHARED_DIR/log.sh"
log_init

PROFILE_NAME="MediaSystem"

log_info "=== Starting ${MODULE_NAME:-unknown} ==="

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

log_info "=== Completed $MODULE_NAME ==="
