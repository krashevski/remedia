#!/usr/bin/env bash
# mediapanel/ui/system.sh

: "${REMEDIA_LIB:?missing REMEDIA_LIB}"
: "${FAST_STORAGE:?missing FAST_STORAGE}"
: "${SLOW_STORAGE:?missing SLOW_STORAGE}"
: "${BACKUP_STORAGE:?missing BACKUP_STORAGE}"
: "${PROJECT_DIR:?missing PROJECT_DIR}"

# SYSTEM_DEPS_PATH="${SYSTEM_DEPS_PATH:-$REMEDIA_LIB/modules/mediapanel/core/system_deps.sh}"

# Shared language preferences; ui/ui.sh does not need modification.
if ! declare -F mediapanel_subtitle_languages_load >/dev/null; then
    # shellcheck source=modules/mediapanel/core/subtitle_languages.sh
    source "$(dirname -- "${BASH_SOURCE[0]}")/../core/subtitle_languages.sh" || return 1
fi

# =========================
# YOUTUBE API RUNTIME
# =========================
youtube_api_python() {
    printf '%s\n' "${REMEDIA_YOUTUBE_PYTHON:-${REMEDIA_YOUTUBE_VENV:-$HOME/.local/share/remedia/youtube-venv}/bin/python}"
}

mediapanel_install_youtube_api() {
    local venv_dir="${REMEDIA_YOUTUBE_VENV:-$HOME/.local/share/remedia/youtube-venv}"
    local py="$venv_dir/bin/python"
    local confirm

    echo
    echo "$(t MP_SYS_YOUTUBE_API_PYTHON_DEPENDENCIES)"
    echo "$(t MP_SYS_VIRTUAL_ENVIRONMENT "$venv_dir")"
    echo "$(t MP_SYS_PACKAGES_GOOGLE_API_PYTHON_CLIENT_GOOGLE_AUTH_OAUTHLIB_GOOGLE_AUTH_HTT)"
    echo "$(t MP_SYS_INSTALLATION_DOWNLOADS_PACKAGES_FROM_PYPI_NO_SUDO_REQUIRED)"
    echo
    read -rp "$(t MP_SYS_INSTALL_UPGRADE_DEPENDENCIES_Y_N)" confirm || return 0
    [[ "$confirm" =~ ^[YyДдИи]$ ]] || { echo "$(t MP_SYS_CANCELLED)"; return 0; }

    if [[ ! -x "$py" ]]; then
        if ! python3 -m venv "$venv_dir"; then
            echo "$(t MP_SYS_ERROR_CANNOT_CREATE_VENV_INSTALL_PYTHON3_VENV_USING_YOUR_PACKAGE_MANAG)"
            return 1
        fi
    fi
    if ! "$py" -m pip --version >/dev/null 2>&1; then
        echo "$(t MP_SYS_ERROR_PIP_MISSING_IN_THE_YOUTUBE_VIRTUAL_ENVIRONMENT)"
        return 1
    fi
    "$py" -m pip install \
        google-api-python-client \
        google-auth-oauthlib \
        google-auth-httplib2 || return 1

    "$py" -c 'import googleapiclient, google_auth_oauthlib, google_auth_httplib2' || return 1
    echo "$(t MP_SYS_OK_YOUTUBE_API_DEPENDENCIES_INSTALLED_AND_IMPORTABLE)"
}

# OAuth setup is modular: no network calls on system status refresh.
YOUTUBE_SETUP_MODULE="${REMEDIA_LIB}/modules/mediapanel/ui/youtube_api_setup.sh"
if [[ -f "$YOUTUBE_SETUP_MODULE" ]]; then
    # shellcheck source=modules/mediapanel/ui/youtube_api_setup.sh
    source "$YOUTUBE_SETUP_MODULE"
else
    mediapanel_youtube_api_status() { echo "$(t MP_SYS_YOUTUBE_SETUP_MISSING)"; }
    mediapanel_youtube_setup_menu() { echo "$(t MP_SYS_ERROR_YOUTUBE_SETUP_MISSING)"; return 1; }
fi

# =========================
# SYSTEM CHECKS
# =========================

mediapanel_require_runtime() {
    : "${REMEDIA_VAR:?missing REMEDIA_VAR}"
    : "${PROJECT_DIR:?missing PROJECT_DIR}"

    if ! declare -f state_get >/dev/null; then
        echo "$(t MP_SYS_FATAL_STATE_SYSTEM_NOT_LOADED)"
        return 1
    fi
}

mediapanel_check_dependencies() {
    command -v ffmpeg >/dev/null || {
        echo "$(t MP_SYS_WARN_FFMPEG_NOT_INSTALLED)"
        return 1
    }

    command -v find >/dev/null || {
        echo "$(t MP_SYS_FATAL_COREUTILS_MISSING)"
        return 1
    }

    return 0
}

mediapanel_system_info() {
    echo "$(t MP_SYS_MEDIAPANEL_SYSTEM)"
    echo "$(t MP_SYS_REMEDIA_VAR "$REMEDIA_VAR")"
    echo "$(t MP_SYS_PROJECT_DIR "$PROJECT_DIR")"
    echo "$(t MP_SYS_ACTIVE_PROJECT "$(state_get active_project)")"
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
        echo "$(t MP_SYS_LOG_LOG_FILE_IS_NOT_SET)"
        return 1
    fi

    # 2. директория существует?
    local dir
    dir="$(dirname "$file")"

    if [[ ! -d "$dir" ]]; then
        echo "$(t MP_SYS_LOG_LOG_DIRECTORY_MISSING "$dir")"
        return 1
    fi

    # 3. файл существует?
    if [[ ! -f "$file" ]]; then
        echo "$(t MP_SYS_LOG_LOG_FILE_NOT_CREATED_YET "$file")"
        echo "$(t MP_SYS_LOG_RUN_INGEST_PIPELINE_FIRST)"
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
        echo "$(t MP_SYS_ERROR_REMEDIA_FILTER_SETS_NOT_FOUND "$source_dir")"
        return 1
    }

    mkdir -p "$target_dir" || {
        echo "$(t MP_SYS_ERROR_CANNOT_CREATE_SHOTCUT_FILTER_SET_DIRECTORY)"
        echo "        $target_dir"
        return 1
    }

    for file in "$source_dir"/*; do
        [[ -f "$file" ]] || continue

        filename="${file##*/}"

        if [[ -e "$target_dir/$filename" ]]; then
            echo "$(t MP_SYS_SKIP_ALREADY_EXISTS "$filename")"
            ((skipped++))
            continue
        fi

        if cp -- "$file" "$target_dir/$filename"; then
            echo "$(t MP_SYS_OK_IMPORTED "$filename")"
            ((copied++))
        else
            echo "$(t MP_SYS_ERROR_FAILED_TO_IMPORT "$filename")"
            return 1
        fi
    done

    echo
    echo "$(t MP_SYS_OK_FILTER_SET_IMPORT_COMPLETED)"
    echo "$(t MP_SYS_IMPORTED "$copied")"
    echo "$(t MP_SYS_EXISTING "$skipped")"
    echo
    echo "$(t MP_SYS_INFO_RESTART_SHOTCUT_TO_LOAD_THE_FILTER_SETS)"
}

show_shotcut_config_status() {
    local shotcut_app="org.shotcut.Shotcut"
    local filter_dir="$HOME/.var/app/$shotcut_app/data/Meltytech/Shotcut/filter-sets"
    local filter_count=0

    echo "$(t MP_SYS_SHOTCUT)"

    # Проверка установки Shotcut Flatpak
    if ! command -v flatpak >/dev/null 2>&1; then
        echo -e "$(t MP_SYS_FLATPAK_NOT_INSTALLED "${COLOR_RED}" "${COLOR_RESET}")"
        echo -e "$(t MP_SYS_SUBTITLES_MODULE_WHISPER_UNAVAILABLE "${COLOR_RED}" "${COLOR_RESET}")"
    elif ! flatpak info "$shotcut_app" >/dev/null 2>&1; then
        echo -e "$(t MP_SYS_FLATPAK_SHOTCUT_NOT_INSTALLED "${COLOR_RED}" "${COLOR_RESET}")"
        echo -e "$(t MP_SYS_SUBTITLES_MODULE_WHISPER_UNAVAILABLE "${COLOR_RED}" "${COLOR_RESET}")"
    else
        echo -e "$(t MP_SYS_FLATPAK_INSTALLED "${COLOR_GREEN}" "${COLOR_RESET}")"

        # Проверка установленного в Shotcut модуля Whisper
        if timeout 10 \
            flatpak run \
                --command=whisper-cli \
                "$shotcut_app" \
                --help >/dev/null 2>&1
        then
            echo -e "$(t MP_SYS_SUBTITLES_MODULE_WHISPER_INSTALLED "${COLOR_GREEN}" "${COLOR_RESET}")"
        else
            echo -e "$(t MP_SYS_SUBTITLES_MODULE_WHISPER_NOT_INSTALLED "${COLOR_YELLOW}" "${COLOR_RESET}")"
        fi
    fi

    mediapanel_subtitle_languages_status
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
        echo -e "$(t MP_SYS_FILTER_SETS_INSTALLED "${COLOR_GREEN}" "$filter_count" "${COLOR_RESET}")"
    else
        echo -e "$(t MP_SYS_FILTER_SETS_NOT_INSTALLED "${COLOR_YELLOW}" "${COLOR_RESET}")"
    fi
}

# NVENC is tested explicitly inside Shotcut Flatpak, never during screen refresh.
mediapanel_shotcut_nvenc_run() {
    local action="${1:-doctor}" code=0
    if [[ "$action" != doctor && "$action" != heal ]]; then
        echo "$(t MP_SYS_ERROR_UNSUPPORTED_SHOTCUT_NVENC_ACTION "$action")"
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
    echo "$(t MP_SYS_SHOTCUT_FLATPAK_NVENC_ACTION_EXIT "$action" "$code")"
    if (( code == 14 )); then
        echo "$(t MP_SYS_CHOOSE_THE_INSTALLATION_EXPLICITLY_WITH_THE_CLI_FOR_EXAMPLE)"
        echo "$(t MP_SYS_REMEDIA_SYSTEM_NVIDIA_FLATPAK_NVENC_SCOPE_SYSTEM "$action")"
    fi
    # A diagnostic failure must not close the MediaPanel UI.
    return 0
}

mediapanel_shotcut_nvenc_status() {
    local code="${MEDIAPANEL_SHOTCUT_NVENC_CODE:-unchecked}"
    local checked="${MEDIAPANEL_SHOTCUT_NVENC_TIME:-}"
    case "$code" in
        unchecked)
            echo "$(t MP_SYS_NVENC_NOT_CHECKED_6_DOCTOR_7_HEAL)"
            ;;
        0)
            echo "$(t MP_SYS_NVENC_LAST_TEST_PASSED_AT_H264_NVENC_640X360 "$checked")"
            ;;
        1)
            echo "$(t MP_SYS_NVENC_LAST_ACTION_CANCELLED_FAILED_AT_RUN_DOCTOR "$checked")"
            ;;
        *)
            echo "$(t MP_SYS_NVENC_LAST_DIAGNOSIS_AT_DETAILS_DOCTOR "$code" "$checked")"
            ;;
    esac
}

mediapanel_subtitle_languages_menu() {
    local input code
    local -a selected=()
    while true; do
        echo
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "$(t MP_SYS_SUBTITLE_LANGUAGES "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        mediapanel_subtitle_languages_status || return 1
        echo
        echo "$(t MP_SYS_ENTER_1_4_LANGUAGE_CODES_IN_PREFERRED_ORDER)"
        echo "$(t MP_SYS_EXAMPLES_RU_KK_EN_EN_JA_DE_FR)"
        echo "$(t MP_SYS_THE_FIRST_LANGUAGE_IS_THE_DEFAULT_FOR_SUBTITLE_GENERATION)"
        echo "$(t MP_SYS_AUTO_DETECT_IS_ALWAYS_AVAILABLE_IN_THE_GENERATION_MENU)"
        echo
        echo "$(t MP_SYS_L_LIST_SUPPORTED_LANGUAGES)"
        echo "$(t MP_SYS_R_RESTORE_DEFAULTS_RU_KK_EN)"
        echo
        echo -e "$(t MP_SYS_0_BACK_WITHOUT_SAVING "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo
        read -r -p "$(t MP_SYS_LANGUAGES)" input || return 0
        input="${input,,}"
        case "$input" in
            0|'') return 0 ;;
            l)
                for code in "${!MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[@]}"; do
                    printf ' %-3s  %s\n' "$code" "$(mediapanel_subtitle_language_name "$code")"
                done | LC_ALL=C sort -k2

                echo
                read -r -p "$(t MP_SYS_PRESS_ENTER_TO_CONTINUE)" _ || return 0
                continue
                ;;
            r) selected=(ru kk en) ;;
            *)
                input="${input//,/ }"
                read -r -a selected <<< "$input"
                ;;
        esac
        if ! mediapanel_subtitle_languages_save "${selected[@]}"; then
            echo "$(t MP_SYS_ERROR_SETTINGS_WERE_NOT_SAVED)"
            continue
        fi
        echo "$(t MP_SYS_OK_SUBTITLE_LANGUAGES_SAVED)"
        return 0
    done
}

# Print the label before safe_du starts; command substitution otherwise hides
# the entire row until directory traversal has finished. Keep counting in the
# foreground and animate only on a terminal (never in redirected output).
mediapanel_show_storage_usage() (
    local label="$1" path="$2" value spinner_pid=""

    trap 'if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
    fi' EXIT
    trap 'printf "\n"; exit 130' INT
    trap 'printf "\n"; exit 143' TERM

    printf '%-20s ' "$label"
    if [[ -t 1 ]]; then
        (
            frames=('|' '/' '-' '\')
            i=0
            while :; do
                printf '\r%-20s [%s]' "$label" "${frames[i % 4]}"
                i=$((i + 1))
                sleep 0.15
            done
        ) &
        spinner_pid=$!
    fi

    value="$(safe_du "$path")" || true

    if [[ -n "$spinner_pid" ]]; then
        kill "$spinner_pid" 2>/dev/null || true
        wait "$spinner_pid" 2>/dev/null || true
        spinner_pid=""
        printf '\r%-20s %s\033[K\n' "$label" "${value:-?}"
    else
        printf '%s\n' "${value:-?}"
    fi
)

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
        echo -e "$(t MP_SYS_SYSTEM_STATUS "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
        echo "$(t MP_SYS_GPU "$GPU")"
        # NVENC status belongs to the Shotcut block below.
        echo
        echo "$(t MP_SYS_PROJECTS "$projects_count")"
        if [[ -n "$active" ]]; then
            echo -e "$(t MP_SYS_ACTIVE_PROJECT_2 "${COLOR_GREEN}" "${active}" "${COLOR_RESET}")"
        else
            echo -e "$(t MP_SYS_ACTIVE_PROJECT_NONE "${COLOR_RED}" "${COLOR_RESET}")"
        fi
        echo
        df -h "$FAST_STORAGE" "$SLOW_STORAGE" "$BACKUP_STORAGE" 2>/dev/null
        echo
        phone_status
        echo
        echo
        show_shotcut_config_status
        echo
        mediapanel_youtube_api_status
        echo
        echo -e "$(t MP_SYS_MENU "${COLOR_BOLD}" "${COLOR_RESET}")"
        echo
        echo "$(t MP_SYS_1_REFRESH)"
        echo "$(t MP_SYS_2_SHOW_SYSTEM_LOG)"
        echo "$(t MP_SYS_3_SHOW_DISK_USAGE)"
        echo "$(t MP_SYS_4_SHOW_GPU_INFO)"
        echo "$(t MP_SYS_5_IMPORT_SHOTCUT_FILTER_SETS)"
        echo "$(t MP_SYS_6_SHOTCUT_FLATPAK_NVENC_DOCTOR)"
        echo "$(t MP_SYS_7_SHOTCUT_FLATPAK_NVENC_HEAL)"
        echo "$(t MP_SYS_8_YOUTUBE_API_SETUP)"
        echo "$(t MP_SYS_9_SUBTITLE_LANGUAGES)"
        echo
        echo -e "$(t MP_SYS_0_BACK "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo
        read -rp "$(t MP_SYS_CHOICE_1)" choice

        case "$choice" in
            1)
                continue
                ;;

            2)
               while true; do
                   clear
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                   echo -e "$(t MP_SYS_SYSTEM_LOG "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                   echo
                   echo "$(t MP_SYS_1_LAST_50_LINES)"
                   echo "$(t MP_SYS_2_LAST_200_LINES)"
                   echo "$(t MP_SYS_3_FOLLOW_LIVE)"
                   echo
                   echo -e "$(t MP_SYS_0_BACK_2 "${COLOR_YELLOW}" "${COLOR_RESET}")"
                   echo

                   read -rp "$(t MP_SYS_LOG_1)" lchoice

                   case "$lchoice" in
                       1)
 #                          tail -n 50 "$LOG_FILE"
                          if safe_log_file "$LOG_FILE"; then
                              tail -n 50 "$LOG_FILE"
                          fi
                          read -rp "$(t MP_SYS_ENTER)"
                          ;;
                       2)
#                          tail -n 200 "$LOG_FILE"
                          if safe_log_file "$LOG_FILE"; then
                              tail -n 200 "$LOG_FILE"
                          fi
                          read -rp "$(t MP_SYS_ENTER)"
                          ;;
                       3)
#                          echo "Press Ctrl+C to stop"
#                          tail -f "$LOG_FILE"
                          if safe_log_file "$LOG_FILE"; then
                              echo "$(t MP_SYS_PRESS_CTRL_C_TO_STOP)"
                              tail -f "$LOG_FILE"
                          else
                              read -rp "$(t MP_SYS_ENTER)"
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
                echo -e "$(t MP_SYS_DISK_DETAILS "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo
                echo -e "$(t MP_SYS_STORAGE_USAGE "${COLOR_BOLD}" "${COLOR_RESET}")"
                echo

                mediapanel_show_storage_usage " FAST_STORAGE:" "$FAST_STORAGE"

                mediapanel_show_storage_usage " SLOW_STORAGE:" "$SLOW_STORAGE"

                mediapanel_show_storage_usage " BACKUP_STORAGE:" "$BACKUP_STORAGE"

                mediapanel_show_storage_usage " PROJECT_DIR:" "$PROJECT_DIR"

                echo
                echo -e "$(t MP_SYS_PATHS "${COLOR_BOLD}" "${COLOR_RESET}")"
                echo
                echo "$(t MP_SYS_FAST_STORAGE "$FAST_STORAGE")"
                echo "$(t MP_SYS_SLOW_STORAGE "$SLOW_STORAGE")"
                echo "$(t MP_SYS_BACKUP_STORAGE "$BACKUP_STORAGE")"
                echo "$(t MP_SYS_PROJECT_DIR_2 "$PROJECT_DIR")"
                echo
                read -rp "$(t MP_SYS_PRESS_ENTER)"
                ;;
            4)
                clear
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo -e "$(t MP_SYS_GPU_INFO "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
                echo
                lspci | grep -i vga
                echo
                echo "$(t MP_SYS_HOST_FFMPEG_ENCODER_LIST_NOT_A_SHOTCUT_FLATPAK_TEST)"
                ffmpeg -encoders 2>/dev/null | grep nvenc ||
                    echo "$(t MP_SYS_HOST_FFMPEG_DOES_NOT_LIST_NVENC_USE_MENU_6_TO_TEST_SHOTCUT_FLATPAK)"
                echo
                read -rp "$(t MP_SYS_PRESS_ENTER)"
                ;;
            5)
                install_shotcut_filter_sets
                read -rp "$(t MP_SYS_PRESS_ENTER_TO_CONTINUE)"
                ;;
            6)
                mediapanel_shotcut_nvenc_run doctor
                read -rp "$(t MP_SYS_PRESS_ENTER_TO_CONTINUE)"
                ;;
            7)
                mediapanel_shotcut_nvenc_run heal
                read -rp "$(t MP_SYS_PRESS_ENTER_TO_CONTINUE)"
                ;;
            8)
                mediapanel_youtube_setup_menu
                ;;
            9)
                mediapanel_subtitle_languages_menu || true
                ;;
            0)
                echo "$(t MP_SYS_BACK)"
                return 0   # если это функция
                # или break  # если это loop внутри скрипта
                ;;
            *)
                echo "$(t MP_SYS_INVALID_OPTION)"
                sleep 1
                ;;
        esac
    done
}
