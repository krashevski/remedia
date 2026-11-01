#!/usr/bin/env bash
# mediapanel/core/system_deps.sh

phone_status_mediapanel() {
    local gvfs="/run/user/$UID/gvfs"

    echo "$(t MP_SYSTEM_DEPS_PHONE)"

    if [[ ! -d "$gvfs" ]]; then
        echo "$(t MP_SYSTEM_DEPS_GVFS_NOT_AVAILABLE)"
        return
    fi

    local mtp
    mtp=$(find "$gvfs" -maxdepth 1 -type d -name "mtp:*" 2>/dev/null | head -n1)

    if [[ -n "$mtp" ]]; then
        echo "$(t MP_SYSTEM_DEPS_ANDROID_DEVICE_DETECTED_MTP)"
        return
    fi

    local afc
    afc=$(find "$gvfs" -maxdepth 1 -type d -name "afc:*" 2>/dev/null | head -n1)

    if [[ -n "$afc" ]]; then
        echo "$(t MP_SYSTEM_DEPS_IPHONE_DETECTED_AFC)"
        return
    fi

    echo "$(t MP_SYSTEM_DEPS_NO_PHONE_DETECTED)"
}

open_video_dialog() {
    local file=""

    # 1. Zenity (GUI диалог)
    if command -v zenity &>/dev/null; then
        file=$(zenity --file-selection \
            --title="$(t MP_DEPS_OPEN_VIDEO)" \
            --file-filter="$(t MP_DEPS_VIDEO_FILES) | *.mp4 *.mkv *.avi *.mov *.webm")

    # 2. KDialog (KDE)
    elif command -v kdialog &>/dev/null; then
        file=$(kdialog --getopenfilename "$HOME" "*.mp4 *.mkv *.avi *.mov *.webm")

    # 3. CLI fallback
    else
        read -rp "$(t MP_SYSTEM_DEPS_ENTER_PATH_TO_VIDEO_FILE)" file
    fi

    # отмена
    [[ -z "$file" ]] && return

    # проверка файла
    if [[ ! -f "$file" ]]; then
        echo "$(t MP_SYSTEM_DEPS_FILE_NOT_FOUND)"
        sleep 1
        return
    fi

    # запуск через VLC (приоритет cmd → flatpak fallback)
    if command -v vlc &>/dev/null; then
        vlc "$file" & disown
    elif has_flatpak "org.videolan.VLC"; then
        flatpak run org.videolan.VLC "$file" & disown
    else
        echo "$(t MP_SYSTEM_DEPS_VLC_NOT_FOUND)"
        sleep 1
    fi
}
