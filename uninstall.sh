#!/usr/bin/env bash
# uninstall.sh

set -euo pipefail

PURGE=false

if [[ "${1:-}" == "--purge" ]]; then
    PURGE=true
fi

echo "[UNINSTALL] removing Remedia..."

rm -rf /usr/lib/remedia
rm -f /usr/bin/remedia
rm -f /usr/bin/remedia-setup
rm -f /usr/bin/remedia-doctor

echo "[UNINSTALL] removing desktop integration..."

rm -f /usr/share/applications/pro-media-panel.desktop

for size in 48 64 128 256; do
    rm -f "/usr/share/icons/hicolor/${size}x${size}/apps/pro-media-panel.png"
done

# 👇 ключевой момент
if [[ "$PURGE" == true ]]; then
    read -rp "Remove config /etc/remedia/remedia.env? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f /etc/remedia/remedia.env
    else
        echo "[UNINSTALL] keeping config at /etc/remedia/remedia.env"
    fi
fi

echo "[UNINSTALL] done"
