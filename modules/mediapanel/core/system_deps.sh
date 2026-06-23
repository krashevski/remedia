#!/usr/bin/env bash
# mediapanel/core/system_deps.sh

phone_status_mediapanel() {
    local gvfs="/run/user/$UID/gvfs"

    echo " Phone:"

    if [[ ! -d "$gvfs" ]]; then
        echo "   GVFS not available"
        return
    fi

    local mtp
    mtp=$(find "$gvfs" -maxdepth 1 -type d -name "mtp:*" 2>/dev/null | head -n1)

    if [[ -n "$mtp" ]]; then
        echo "   Android device detected (MTP)"
        return
    fi

    local afc
    afc=$(find "$gvfs" -maxdepth 1 -type d -name "afc:*" 2>/dev/null | head -n1)

    if [[ -n "$afc" ]]; then
        echo "   iPhone detected (AFC)"
        return
    fi

    echo "   No phone detected"
}

open_video_dialog() {
    local file=""

    # 1. Zenity (GUI диалог)
    if command -v zenity &>/dev/null; then
        file=$(zenity --file-selection \
            --title="Open video" \
            --file-filter="Video files | *.mp4 *.mkv *.avi *.mov *.webm")

    # 2. KDialog (KDE)
    elif command -v kdialog &>/dev/null; then
        file=$(kdialog --getopenfilename "$HOME" "*.mp4 *.mkv *.avi *.mov *.webm")

    # 3. CLI fallback
    else
        read -rp "Enter path to video file: " file
    fi

    # отмена
    [[ -z "$file" ]] && return

    # проверка файла
    if [[ ! -f "$file" ]]; then
        echo "File not found"
        sleep 1
        return
    fi

    # запуск через VLC (приоритет cmd → flatpak fallback)
    if command -v vlc &>/dev/null; then
        vlc "$file" & disown
    elif has_flatpak "org.videolan.VLC"; then
        flatpak run org.videolan.VLC "$file" & disown
    else
        echo "VLC not found"
        sleep 1
    fi
}
