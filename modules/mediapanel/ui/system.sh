#!/usr/bin/env bash
# mediapanel/ui/system.sh

: "${REMEDIA_LIB:?missing REMEDIA_LIB}"
: "${FAST_STORAGE:?missing FAST_STORAGE}"
: "${SLOW_STORAGE:?missing SLOW_STORAGE}"
: "${BACKUP_STORAGE:?missing BACKUP_STORAGE}"
: "${PROJECT_DIR:?missing PROJECT_DIR}"

# SYSTEM_DEPS_PATH="${SYSTEM_DEPS_PATH:-$REMEDIA_LIB/modules/mediapanel/core/system_deps.sh}"

# =========================
# SYSTEM CHECKS
# =========================

mediapanel_require_runtime() {
    : "${REMEDIA_VAR:?missing REMEDIA_VAR}"
    : "${PROJECT_DIR:?missing PROJECT_DIR}"

    if ! declare -f state_get >/dev/null; then
        echo "[FATAL] state system not loaded"
        return 1
    fi
}

mediapanel_check_dependencies() {
    command -v ffmpeg >/dev/null || {
        echo "[WARN] ffmpeg not installed"
        return 1
    }

    command -v find >/dev/null || {
        echo "[FATAL] coreutils missing"
        return 1
    }

    return 0
}

mediapanel_system_info() {
    echo "[MediaPanel System]"
    echo "REMEDIA_VAR=$REMEDIA_VAR"
    echo "PROJECT_DIR=$PROJECT_DIR"
    echo "ACTIVE_PROJECT=$(state_get active_project)"
}

phone_status() {
    phone_status_base

    # безопасный вызов (если функция существует)
    if declare -f phone_status_mediapanel >/dev/null; then
        phone_status_mediapanel
    fi
}

safe_log_file() {
    local file="$1"

    # 1. переменная не задана
    if [[ -z "${file:-}" ]]; then
        echo "[LOG] LOG_FILE is not set"
        return 1
    fi

    # 2. директория существует?
    local dir
    dir="$(dirname "$file")"

    if [[ ! -d "$dir" ]]; then
        echo "[LOG] log directory missing: $dir"
        return 1
    fi

    # 3. файл существует?
    if [[ ! -f "$file" ]]; then
        echo "[LOG] log file not created yet: $file"
        echo "[LOG] (run ingest / pipeline first)"
        return 1
    fi

    return 0
}

ensure_log_file() {
    local active="$1"

    [[ -z "$active" ]] && return 1

    local dir="$PROJECT_DIR/$active"
    local file="$dir/.log"

    mkdir -p "$dir"

    [[ -f "$file" ]] || : > "$file"

    echo "$file"
}

install_shotcut_filter_sets() {
    local source_dir="/usr/share/remedia/filter-sets"
    local target_dir="$HOME/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/filter-sets"
    local copied=0
    local skipped=0
    local file
    local filename

    [[ -d "$source_dir" ]] || {
        echo "[ERROR] Remedia filter sets not found: $source_dir"
        return 1
    }

    mkdir -p "$target_dir" || {
        echo "[ERROR] Cannot create Shotcut filter-set directory:"
        echo "        $target_dir"
        return 1
    }

    for file in "$source_dir"/*; do
        [[ -f "$file" ]] || continue

        filename="${file##*/}"

        if [[ -e "$target_dir/$filename" ]]; then
            echo "[SKIP] $filename already exists"
            ((skipped++))
            continue
        fi

        if cp -- "$file" "$target_dir/$filename"; then
            echo "[OK] imported: $filename"
            ((copied++))
        else
            echo "[ERROR] failed to import: $filename"
            return 1
        fi
    done

    echo
    echo "[OK] Filter-set import completed"
    echo "     Imported: $copied"
    echo "     Existing: $skipped"
    echo
    echo "[INFO] Restart Shotcut to load the filter sets."
}

show_shotcut_config_status() {
    local shotcut_app="org.shotcut.Shotcut"
    local filter_dir="$HOME/.var/app/$shotcut_app/data/Meltytech/Shotcut/filter-sets"
    local filter_count=0

    echo "Shotcut:"

    # Проверка установки Shotcut Flatpak
    if ! command -v flatpak >/dev/null 2>&1; then
        echo -e "   Flatpak: ${COLOR_RED}not installed${COLOR_RESET}"
        echo -e "   Subtitles module (Whisper): ${COLOR_RED}unavailable${COLOR_RESET}"
    elif ! flatpak info "$shotcut_app" >/dev/null 2>&1; then
        echo -e "   Flatpak: ${COLOR_RED}Shotcut not installed${COLOR_RESET}"
        echo -e "   Subtitles module (Whisper): ${COLOR_RED}unavailable${COLOR_RESET}"
    else
        echo -e "   Flatpak: ${COLOR_GREEN}installed${COLOR_RESET}"

        # Проверка установленного в Shotcut модуля Whisper
        if timeout 10 \
            flatpak run \
                --command=whisper-cli \
                "$shotcut_app" \
                --help >/dev/null 2>&1
        then
            echo -e "   Subtitles module (Whisper): ${COLOR_GREEN}installed${COLOR_RESET}"
        else
            echo -e "   Subtitles module (Whisper): ${COLOR_YELLOW}not installed${COLOR_RESET}"
        fi
    fi

    mediapanel_shotcut_nvenc_status

    # Количество импортированных наборов фильтров
    if [[ -d "$filter_dir" ]]; then
        filter_count="$(
            find "$filter_dir" \
                -mindepth 1 \
                -maxdepth 1 \
                -type f \
                -printf '.' 2>/dev/null |
            wc -c
        )"
    fi

    if (( filter_count > 0 )); then
        echo -e "   Filter sets: ${COLOR_GREEN}$filter_count installed${COLOR_RESET}"
    else
        echo -e "   Filter sets: ${COLOR_YELLOW}not installed${COLOR_RESET}"
    fi
}

# NVENC is tested explicitly inside Shotcut Flatpak, never during screen refresh.
mediapanel_shotcut_nvenc_run() {
    local action="${1:-doctor}" code=0
    if [[ "$action" != doctor && "$action" != heal ]]; then
        echo "[ERROR] unsupported Shotcut NVENC action: $action"
        return 2
    fi
    if remedia system nvidia-flatpak-nvenc "$action"; then
        code=0
    else
        code=$?
    fi
    MEDIAPANEL_SHOTCUT_NVENC_CODE="$code"
    MEDIAPANEL_SHOTCUT_NVENC_TIME="$(date '+%H:%M:%S')"
    echo
    echo "[Shotcut Flatpak NVENC] action=$action exit=$code"
    if (( code == 14 )); then
        echo 'Choose the installation explicitly with the CLI, for example:'
        echo "  remedia system nvidia-flatpak-nvenc $action --scope=system"
    fi
    # A diagnostic failure must not close the MediaPanel UI.
    return 0
}

mediapanel_shotcut_nvenc_status() {
    local code="${MEDIAPANEL_SHOTCUT_NVENC_CODE:-unchecked}"
    local checked="${MEDIAPANEL_SHOTCUT_NVENC_TIME:-}"
    case "$code" in
        unchecked)
            echo '   NVENC: not checked (6: Doctor, 7: Heal)'
            ;;
        0)
            echo "   NVENC: last test PASSED at $checked (h264_nvenc, 640x360)"
            ;;
        1)
            echo "   NVENC: last action cancelled/failed at $checked; run Doctor"
            ;;
        *)
            echo "   NVENC: last diagnosis $code at $checked (details: Doctor)"
            ;;
    esac
}

system_status() {
    while true; do
        active="$(get_active_project)"
#        LOG_FILE="$PROJECT_DIR/$active/.log"
        LOG_FILE="$(ensure_log_file "$active" || true)"
        echo
        clear

        local GPU projects_count

        GPU="$(get_gpu_cached)"
        # Shotcut NVENC is checked only via menu 6/7.

        local projects_count=0
        [[ -d "$PROJECT_DIR" ]] && \
            projects_count=$(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                 ${COLOR_BOLD}${COLOR_CYAN}SYSTEM STATUS${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
        echo " GPU:      $GPU"
        # NVENC status belongs to the Shotcut block below.
        echo
        echo " Projects: $projects_count"
        if [[ -n "$active" ]]; then
            echo -e " Active project: ${COLOR_GREEN}${active}${COLOR_RESET}"
        else
            echo -e " Active project: ${COLOR_RED}none${COLOR_RESET}"
        fi
        echo
        df -h "$FAST_STORAGE" "$SLOW_STORAGE" "$BACKUP_STORAGE" 2>/dev/null
        echo
        phone_status
        echo
        echo
        show_shotcut_config_status
        echo
        echo -e "${COLOR_BOLD}MENU:${COLOR_RESET}"
        echo
        echo " 1) Refresh"
        echo " 2) Show system log"
        echo " 3) Show disk usage"
        echo " 4) Show GPU info"
        echo " 5) Import Shotcut filter sets"
        echo " 6) Shotcut Flatpak NVENC doctor"
        echo " 7) Shotcut Flatpak NVENC heal"
        echo
        echo -e " ${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Choice [1-#]: " choice

        case "$choice" in
            1)
                continue
                ;;

            2)
               while true; do
                   clear
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                   echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}SYSTEM LOG${COLOR_RESET}"
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                   echo
                   echo "1) Last 50 lines"
                   echo "2) Last 200 lines"
                   echo "3) Follow (live)"
                   echo
                   echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
                   echo

                   read -rp "log [1-#]> " lchoice

                   case "$lchoice" in
                       1)
 #                          tail -n 50 "$LOG_FILE"
                          if safe_log_file "$LOG_FILE"; then
                              tail -n 50 "$LOG_FILE"
                          fi
                          read -rp "Enter..."
                          ;;
                       2)
#                          tail -n 200 "$LOG_FILE"
                          if safe_log_file "$LOG_FILE"; then
                              tail -n 200 "$LOG_FILE"
                          fi
                          read -rp "Enter..."
                          ;;
                       3)
#                          echo "Press Ctrl+C to stop"
#                          tail -f "$LOG_FILE"
                          if safe_log_file "$LOG_FILE"; then
                              echo "Press Ctrl+C to stop"
                              tail -f "$LOG_FILE"
                          else
                              read -rp "Enter..."
                          fi
                          ;;
                       0)
                          break
                          ;;
                  esac
                done
                ;;
            3)
                clear
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}DISK DETAILS${COLOR_RESET}"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo
                echo -e "${COLOR_BOLD}Storage usage:${COLOR_RESET}"
                echo

                printf "%-20s %s\n" " FAST_STORAGE:" "$(safe_du "$FAST_STORAGE")"

                printf "%-20s %s\n" " SLOW_STORAGE:" "$(safe_du "$SLOW_STORAGE")"

                printf "%-20s %s\n" " BACKUP_STORAGE:" "$(safe_du "$BACKUP_STORAGE")"

                printf "%-20s %s\n" " PROJECT_DIR:" "$(safe_du "$PROJECT_DIR")"

                echo
                echo -e "${COLOR_BOLD}Paths:${COLOR_RESET}"
                echo
                echo " FAST_STORAGE   = $FAST_STORAGE"
                echo " SLOW_STORAGE   = $SLOW_STORAGE"
                echo " BACKUP_STORAGE = $BACKUP_STORAGE"
                echo " PROJECT_DIR    = $PROJECT_DIR"
                echo
                read -rp "Press Enter..."
                ;;
            4)
                clear
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}GPU INFO${COLOR_RESET}"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo
                lspci | grep -i vga
                echo
                echo "Host FFmpeg encoder list (not a Shotcut Flatpak test):"
                ffmpeg -encoders 2>/dev/null | grep nvenc ||
                    echo "Host FFmpeg does not list NVENC; use menu 6 to test Shotcut Flatpak"
                echo
                read -rp "Press Enter..."
                ;;
            5)
                install_shotcut_filter_sets
                read -rp "Press Enter to continue..."
                ;;
            6)
                mediapanel_shotcut_nvenc_run doctor
                read -rp "Press Enter to continue..."
                ;;
            7)
                mediapanel_shotcut_nvenc_run heal
                read -rp "Press Enter to continue..."
                ;;
            0)
                echo "Back..."
                return 0   # если это функция
                # или break  # если это loop внутри скрипта
                ;;
            *)
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}
