#!/usr/bin/env bash
# modules/system/modules/dpkg/upgrade.sh

dpkg_upgrade() {
    echo "[ACTION] upgrading system packages..."
    sudo apt update
    sudo apt upgrade -y
}

dpkg_full_upgrade() {
    echo "[ACTION] full system upgrade (may install/remove packages)..."
    if [[ "${REMEDIA_FORCE:-0}" != "1" ]]; then
        echo "[CONFIRM] full-upgrade may remove/install packages"
        read -p "Continue? (y/N): " ans
        [[ "$ans" == "y" ]] || return 1
    fi

    sudo apt update
    sudo apt full-upgrade -y
}

