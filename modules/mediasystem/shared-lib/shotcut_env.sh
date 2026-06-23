#!/usr/bin/env bash
# shared-lib/shotcut_env.sh

shotcut_detect_mode() {
    if [[ -d "$HOME/.var/app/org.shotcut.Shotcut" ]]; then
        echo "flatpak"
    else
        echo "native"
    fi
}

shotcut_config_dir() {
    local mode
    mode="$(shotcut_detect_mode)"

    case "$mode" in
        flatpak)
            echo "$HOME/.var/app/org.shotcut.Shotcut/config/shotcut"
            ;;
        native)
            echo "$HOME/.config/Shotcut"
            ;;
    esac
}

shotcut_write_presets() {
    local presets=("$@")

    local dir
    dir="$(shotcut_config_dir)"

    local file="$dir/user.presets.xml"

    mkdir -p "$dir"

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<presets>'

        for preset in "${presets[@]}"; do
            printf '  <encoder>%s</encoder>\n' "$preset"
        done

        echo '</presets>'
    } > "$file"

    echo "[SHOTCUT] wrote presets to $file"
}

shotcut_sync_log() {
    local dir
    dir="$(shotcut_config_dir)"

    {
        echo "=== $(date) ==="
        echo "Shotcut presets sync"
        printf '%s\n' "$@"
        echo
    } >> "$dir/sync.log"
}
