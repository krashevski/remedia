#!/usr/bin/env bash
# modules/system/modules/dpkg/fix.sh

dpkg_fix() {
    echo "[ACTION] fixing dpkg state..."
    sudo dpkg --configure -a
    sudo apt -f install -y
}
