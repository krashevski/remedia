#!/usr/bin/env bash
# install.sh

set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || {
    echo "[FATAL] installer must run as root"
    exit 1
}

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
NC=$'\033[0m'

echo "${GREEN}REMENDIA INSTALL${NC}"

# --- дефолты ---
DEFAULT_FAST="/mnt/shotcut"
DEFAULT_SLOW="/mnt/storage"
DEFAULT_BACKUP="/mnt/backups"

if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    FAST="$DEFAULT_FAST"
    SLOW="$DEFAULT_SLOW"
    BACKUP="$DEFAULT_BACKUP"
fi

select_from_list() {
    local label="$1"
    shift
    local options=("$@")

    echo
    echo "$label:"
    
    local i=1
    for opt in "${options[@]}"; do
        echo "  $i) $opt"
        ((i++))
    done

    echo "  0) Enter manually"

    read -rp "Select option: " choice

    # ручной ввод
    if [[ "$choice" == "0" ]]; then
        read -rp "Enter path: " manual
        echo "$manual"
        return
    fi

    # проверка числа
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#options[@]} )); then
        echo "[FATAL] invalid selection"
        exit 1
    fi

    # вытащить только путь (без размера)
    echo "${options[$((choice-1))]}" | awk '{print $1}'
}

list_mounts() {
    lsblk -o NAME,SIZE,MOUNTPOINT,TYPE -nr | awk '
        $3 != "" && $4 == "part" {
            mp=$3
            # ❌ мусор
            if (mp ~ "^/snap") next
            if (mp == "/") next
            if (mp ~ "^/boot") next
            if (mp ~ "^/run") next
            if (mp ~ "^/proc") next
            if (mp ~ "^/sys") next

            # ✅ оставляем только полезное
            if (mp ~ "^/mnt" || mp ~ "^/media" || mp ~ "^/home") {
                print mp " (" $2 ")"
            }
        }
    '
}

ask_path() {
    local label="$1"
    local default="$2"
    local value

    mapfile -t mounts < <(list_mounts)

    {
        echo
        echo "$label:"
        echo "  [Enter] use default → $default"

        local i=1
        for opt in "${mounts[@]}"; do
            mp="$(echo "$opt" | awk '{print $1}')"

            if [[ "$mp" == "$default" ]]; then
                echo "  $i) $opt ${YELLOW}[default]${NC}"
            else
                echo "  $i) $opt"
            fi

            ((i++))
        done
        echo "  m) enter manually"
    } >&2   # 👉 ВСЁ UI → stderr

    read -rp "Select option [1-#]: " choice >&2

    if [[ -z "$choice" ]]; then
        value="$default"

    elif [[ "$choice" == "m" ]]; then
        read -rp "Enter path: " value >&2

    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#mounts[@]} )); then
        value="$(echo "${mounts[$((choice-1))]}" | awk '{print $1}')"

    else
        echo "[FATAL] invalid selection" >&2
        exit 1
    fi

    # --- валидация ---
    if [[ "$value" != /* ]]; then
        echo "[FATAL] path must be absolute: $value" >&2
        exit 1
    fi

    if [[ ! -d "$value" ]]; then
        echo "[INFO] creating $value" >&2
        mkdir -p "$value" || {
            echo "[FATAL] cannot create directory: $value" >&2
            exit 1
        }
    fi

    if [[ ! -w "$value" ]]; then
        echo "[FATAL] no write permission: $value" >&2
        exit 1
    fi

    echo "$value"   # 👉 ТОЛЬКО значение → stdout
}

# --- текущие значения (если есть env) ---
FAST="${FAST_STORAGE:-$DEFAULT_FAST}"
SLOW="${SLOW_STORAGE:-$DEFAULT_SLOW}"
BACKUP="${BACKUP_STORAGE:-$DEFAULT_BACKUP}"

clear
echo "==========================================="
echo "         REMEDIA INSTALL CONFIG"
echo "============================================"
echo
echo "To ensure the system works correctly, configure full storage paths."
echo "1) FAST storage for video editor proxy."
echo "2) SLOW storage for user big files."
echo "3) BACKUP storage for archives."
echo
echo "Press Enter to accept the default value."

# --- input ---
FAST="$(ask_path "FAST storage" "$FAST")"
SLOW="$(ask_path "SLOW storage" "$SLOW")"
BACKUP="$(ask_path "BACKUP storage" "$BACKUP")"

if [[ "$FAST" == "$SLOW" || "$FAST" == "$BACKUP" || "$SLOW" == "$BACKUP" ]]; then
    echo "[ERROR] storages must be different"
    exit 1
fi

check_space() {
    local path="$1"
    local min_gb="$2"

    local avail
    avail=$(df -BG "$path" | awk 'NR==2 {gsub("G","",$4); print $4}')

    if (( avail < min_gb )); then
        echo "[WARN] low disk space on $path (${avail}GB)"
    fi
}

echo
echo "------------------------------------------"
echo "Final configuration:"
echo "FAST = $FAST"
echo "SLOW = $SLOW"
echo "BACKUP = $BACKUP"
echo "------------------------------------------"
echo

read -rp "Continue installation? [Y/n]: " confirm
confirm="${confirm:-Y}"

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
echo "Installation canceled."
exit 1
fi

# --- save ---
CONFIG_FILE="/etc/remedia/remedia.env"

sudo mkdir -p /etc/remedia

sudo tee "$CONFIG_FILE" > /dev/null <<EOF
FAST_STORAGE="$FAST"
SLOW_STORAGE="$SLOW"
BACKUP_STORAGE="$BACKUP"
EOF

mkdir -p "$FAST" "$SLOW" "$BACKUP"

echo "${GREEN}[OK]${NC} Configuration saved into $CONFIG_FILE"

PREFIX="/usr/"
REMEDIA_LIB="$PREFIX/lib/remedia"

echo "[INSTALL] start install"

mkdir -p "$REMEDIA_LIB/core"
mkdir -p "$REMEDIA_LIB/core/utils"
mkdir -p "$REMEDIA_LIB/modules"
mkdir -p /var/log/remedia
mkdir -p /var/lib/remedia

cp -f core/guard.sh   "$REMEDIA_LIB/core/"
cp -f core/kernel.sh   "$REMEDIA_LIB/core/"
cp -f core/prelude.sh  "$REMEDIA_LIB/core/"
cp -f core/env.sh  "$REMEDIA_LIB/core/"
cp -f core/runtime_prelude.sh  "$REMEDIA_LIB/core/"
cp -f core/runtime_guard.sh  "$REMEDIA_LIB/core/"

cp -f core/runtime_init.sh  "$REMEDIA_LIB/core/"

cp -f core/utils/colors.sh  "$REMEDIA_LIB/core/utils/"
cp -f core/utils/log.sh  "$REMEDIA_LIB/core/utils/"
cp -f core/utils/debug.sh  "$REMEDIA_LIB/core/utils/"
cp -f core/config.sh  "$REMEDIA_LIB/core/"
cp -f core/user_context.sh  "$REMEDIA_LIB/core/"
cp -f core/storage.sh  "$REMEDIA_LIB/core/"
cp -f core/state.sh  "$REMEDIA_LIB/core/"
cp -f core/bootstrap.sh  "$REMEDIA_LIB/core/"

cp -f core/runtime_runtime.sh "$REMEDIA_LIB/core/"
cp -f core/system_bootstrap.sh "$REMEDIA_LIB/core/"

cp -f core/router.sh "$REMEDIA_LIB/core/"
cp -f core/registry.sh "$REMEDIA_LIB/core/"
cp -f core/security.sh  "$REMEDIA_LIB/core/"
cp -f core/cache.sh  "$REMEDIA_LIB/core/"

cp -f core/utils/fs.sh  "$REMEDIA_LIB/core/utils/"
cp -f core/runtime.sh  "$REMEDIA_LIB/core/"

cp -f core/runtime_env.sh  "$REMEDIA_LIB/core/"
cp -f core/version.sh   "$REMEDIA_LIB/core/"
cp -f core/hooks.sh "$REMEDIA_LIB/core/"
cp -f core/help.sh   "$REMEDIA_LIB/core/"

echo "[INSTALL] verifying runtime paths..."

test -d /usr/lib/remedia/core || {
    echo "[FATAL] core not installed"
    exit 1
}

for m in modules/*; do
    [[ -d "$m" ]] || continue
    name="$(basename "$m")"

    echo "[INSTALL] module: $name"

    mkdir -p "$REMEDIA_LIB/modules/$name"
    cp -r "$m/"* "$REMEDIA_LIB/modules/$name/"
done

cp -f bin/remedia /usr/bin/remedia
cp -f bin/remedia-setup /usr/bin/remedia-setup
cp -f bin/remedia-doctor /usr/bin/remedia-doctor
chmod +x /usr/bin/remedia

# -----------------------------
# SYSTEM BOOTSTRAP (ROOT ONLY)
# -----------------------------

echo "[INSTALL] system phase..."
source "$REMEDIA_LIB/core/system_bootstrap.sh"
init_backupkit_system_fs

# -----------------------------
# DESKTOP INTEGRATION
# -----------------------------

SYSTEM_DESKTOP="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor"
SYSTEM_BIN="/usr/bin"

echo "[INSTALL] desktop integration..."

# 1. .desktop файл
if [[ -f modules/mediapanel/desktop/mediapanel.desktop ]]; then
    echo "[INSTALL] installing .desktop file..."
    cp -f modules/mediapanel/desktop/mediapanel.desktop "$SYSTEM_DESKTOP/"
else
    echo "[WARN] desktop file not found"
fi

# 2. Иконки
echo "[INSTALL] installing icons..."

for size in 48 64 128 256; do
    if [[ -f "modules/mediapanel/images/${size}x${size}/mediapanel.png" ]]; then
        mkdir -p "$ICON_DIR/${size}x${size}/apps"
        cp "modules/mediapanel/images/${size}x${size}/mediapanel.png" \
           "$ICON_DIR/${size}x${size}/apps/mediapanel.png"
    else
        echo "[WARN] icon ${size}x${size} missing"
    fi
done

# 3. Обновление кэша (не критично если упадёт)
echo "[INSTALL] updating icon cache..."

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache "$ICON_DIR" || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$SYSTEM_DESKTOP" || true
fi

echo "[INSTALL] done"

echo
echo "==========================================="
echo "            INSTALL COMPLETE"
echo "==========================================="
echo
echo "Remedia is successfully installed."
echo
echo "Start the system UI:"
echo "  remedia system center"
echo
echo "Other useful commands:"
echo "  remedia backupkit home doctor"
echo "  remedia mediapanel ui"
echo
