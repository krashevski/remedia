#!/usr/bin/env bash
# modules/system/modules/dpkg/heal.sh

dpkg_heal() {
    echo "[ACTION] aggressive recovery..."
    if [[ "$cmd" == "heal" && "${REMEDIA_FORCE:-0}" != "1" ]]; then
        echo "[CONFIRM] dangerous operation: dpkg heal"
        read -p "Continue? (y/N): " ans
        [[ "$ans" == "y" ]] || exit 1
    fi

    if pgrep -x apt >/dev/null || pgrep -x dpkg >/dev/null; then
        echo "[ERROR] apt/dpkg is running → abort"
        return 1
    fi

    sudo rm -f /var/lib/dpkg/lock*
    sudo rm -f /var/cache/apt/archives/lock
    
    echo "[ACTION] cleaning apt/dpkg state..."
    sudo killall -9 apt apt-get dpkg 2>/dev/null || true

    sudo dpkg --configure -a
    sudo apt -f install -y
    sudo apt update
}
