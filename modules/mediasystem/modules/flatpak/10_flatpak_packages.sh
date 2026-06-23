#!/usr/bin/env bash
# 10_flatpak_packages.sh

set -euo pipefail

: "${SHARED_DIR:?}"

export MODULE_NAME="${MODULE_NAME:-$(basename "${BASH_SOURCE[0]}")}"

source "$SHARED_DIR/log.sh"
log_init_once
source "$SHARED_DIR/ui.sh"

log_info "=== Starting $MODULE_NAME ==="

declare -A FLATPAK_PACKAGES=(
    ["org.shotcut.Shotcut"]="user"
    ["org.gimp.GIMP"]="user"
    ["org.audacityteam.Audacity"]="user"
)

TOTAL=${#FLATPAK_PACKAGES[@]}
if [[ "$TOTAL" -eq 0 ]]; then
    log_warn "No flatpak packages defined"
    log_info "=== Completed $MODULE_NAME ==="
    exit 0
fi

COUNT=0

for PKG in "${!FLATPAK_PACKAGES[@]}"; do
    COUNT=$((COUNT + 1))
    MODE="${FLATPAK_PACKAGES[$PKG]}"

    PROGRESS=$((COUNT * 100 / TOTAL))
    echo -ne "["
    for ((i=0; i<PROGRESS/5; i++)); do echo -n "#"; done
    for ((i=PROGRESS/5; i<20; i++)); do echo -n " "; done
    echo -ne "] ${PROGRESS}% ($COUNT/$TOTAL)\r"

    cmd=(flatpak install -y flathub "$PKG")

    if [[ "$MODE" == "user" ]]; then
        cmd+=(--user)
    else
        cmd+=(--system)
    fi

    if ! "${cmd[@]}" >> "$LOG_FILE" 2>&1; then
        log_warn "Failed to install $PKG"
    else
        log_info "Installed $PKG"
    fi
done

echo -e "\n[####################] 100% ($TOTAL/$TOTAL)"

log_info "=== Completed $MODULE_NAME ==="
