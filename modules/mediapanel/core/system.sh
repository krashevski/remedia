#!/usr/bin/env bash
# mediapanel/core/system.sh

: "${REMEDIA_LIB:?missing REMEDIA_LIB}"
: "${FAST_STORAGE:?missing FAST_STORAGE}"
: "${SLOW_STORAGE:?missing SLOW_STORAGE}"
if [[ -z "${BACKUP_STORAGE:-}" ]]; then
    echo "$(t MP_SYSTEM_FATAL_BACKUP_STORAGE_IS_EMPTY)"
    return 1
fi
: "${PROJECT_DIR:?missing PROJECT_DIR}"

# =========================
# SYSTEM CHECKS
# =========================

mediapanel_require_runtime() {
    runtime_assert_ready || return 1

    : "${REMEDIA_LIB:?missing REMEDIA_LIB}"
    : "${CACHE_DIR:?missing CACHE_DIR}"
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

system_status() {
    mediapanel_require_runtime || return 1
    while true; do
        active="$(get_active_project)"
        LOG_FILE="$PROJECT_DIR/$active/.log"
        echo
        clear        
        
        local GPU NVENC projects_count     
        
        GPU="$(get_gpu_cached)"
        NVENC="$(get_nvenc_cached)"       
   

        local projects_count=0
        [[ -d "$PROJECT_DIR" ]] && \
            projects_count=$(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
        echo -e "$(t MP_SYS_SYSTEM_STATUS "${COLOR_BOLD}" "${COLOR_CYAN}" "${RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
        echo
        echo "$(t MP_SYS_GPU "$GPU")"
        case "$NVENC" in
            YES)
                if [[ "$NVENC" == "YES" ]]; then
                    echo -e "$(t MP_SYSTEM_NVENC_AVAILABLE_H264_HEVC "${COLOR_GREEN}" "${RESET}")"
                fi
                ;;
            NO_FFMPEG)
                echo -e "$(t MP_SYSTEM_NVENC_FFMPEG_MISSING_NVENC "${COLOR_YELLOW}" "${RESET}")"
                ;;
            NO_GPU)
                echo -e "$(t MP_SYSTEM_NVENC_NO_NVIDIA_GPU "${COLOR_RED}" "${RESET}")"
                ;;
            *)
                echo -e "$(t MP_SYSTEM_NVENC_UNKNOWN "${COLOR_RED}" "${RESET}")"
                ;;
        esac 
        echo
        echo "$(t MP_SYS_PROJECTS "$projects_count")"
        if [[ -n "$active" ]]; then
            echo -e "$(t MP_SYS_ACTIVE_PROJECT_2 "${COLOR_GREEN}" "${active}" "${RESET}")"
        else
            echo -e "$(t MP_SYS_ACTIVE_PROJECT_NONE "${COLOR_RED}" "${RESET}")"
        fi
        echo
        df -h "$FAST_STORAGE" "$SLOW_STORAGE" "$BACKUP_STORAGE" 2>/dev/null
        echo
        phone_status
        echo
        echo -e "$(t MP_SYS_MENU "${COLOR_BOLD}" "${RESET}")"
        echo
        echo "$(t MP_SYS_1_REFRESH)"
        echo "$(t MP_SYS_2_SHOW_SYSTEM_LOG)"
        echo "$(t MP_SYS_3_SHOW_DISK_USAGE)"
        echo "$(t MP_SYS_4_SHOW_GPU_INFO)"
        echo
        echo -e "$(t MP_SYSTEM_5_BACK "${COLOR_CYAN}" "${RESET}")"
        echo
        read -rp "$(t MP_SYSTEM_CHOICE_1_5)" choice

        case "$choice" in
            1)
                continue
                ;;

            2)
               while true; do
                   clear
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                   echo -e "$(t MP_SYS_SYSTEM_LOG "${COLOR_BOLD}" "${COLOR_CYAN}" "${RESET}")"
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                   echo
                   echo "$(t MP_SYS_1_LAST_50_LINES)"
                   echo "$(t MP_SYS_2_LAST_200_LINES)"
                   echo "$(t MP_SYS_3_FOLLOW_LIVE)"
                   echo
                   echo -e "$(t MP_SYSTEM_4_BACK "${COLOR_CYAN}" "${RESET}")"
                   echo

                   read -rp "$(t MP_SYSTEM_LOG_1_4)" lchoice

                   case "$lchoice" in
                       1)
                          tail -n 50 "$LOG_FILE"
                          read -rp "$(t MP_SYS_ENTER)"
                          ;;
                       2)
                          tail -n 200 "$LOG_FILE"
                          read -rp "$(t MP_SYS_ENTER)"
                          ;;
                       3)
                          echo "$(t MP_SYS_PRESS_CTRL_C_TO_STOP)"
                          tail -f "$LOG_FILE"
                          ;;
                       4)
                          break
                          ;;
                  esac
                done
                ;;
            3)
                clear
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo -e "$(t MP_SYS_DISK_DETAILS "${COLOR_BOLD}" "${COLOR_CYAN}" "${RESET}")"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo
                echo -e "$(t MP_SYS_STORAGE_USAGE "${COLOR_BOLD}" "${RESET}")"
                echo
                
                printf "%-20s %s\n" "FAST_STORAGE:" "$(get_dir_size_cached "$FAST_STORAGE" || echo 'ERR')"
                printf "%-20s %s\n" "SLOW_STORAGE:" "$(get_dir_size_cached "$SLOW_STORAGE" || echo 'ERR')"
                printf "%-20s %s\n" "BACKUP_STORAGE:" "$(get_dir_size_cached "$BACKUP_STORAGE" || echo 'ERR')"
                printf "%-20s %s\n" "PROJECT_DIR:" "$(get_dir_size_cached "$PROJECT_DIR" || echo 'ERR')"
                
                echo
                echo -e "$(t MP_SYS_PATHS "${COLOR_BOLD}" "${RESET}")"
                echo
                echo "$(t MP_SYS_FAST_STORAGE "$FAST_STORAGE")"
                echo "$(t MP_SYS_SLOW_STORAGE "$SLOW_STORAGE")"
                echo "$(t MP_SYS_BACKUP_STORAGE "$BACKUP_STORAGE")"
                echo "$(t MP_SYS_PROJECT_DIR_2 "$PROJECT_DIR")"
                echo
                read -rp "$(t MP_UI_PRESS_ENTER)"
                ;;
            4)
                clear
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo -e "$(t MP_SYS_GPU_INFO "${COLOR_BOLD}" "${COLOR_CYAN}" "${RESET}")"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo
                lspci | grep -i vga
                echo
                ffmpeg -encoders 2>/dev/null | grep nvenc || echo "$(t MP_SYSTEM_NVENC_NOT_AVAILABLE)"
                echo
                read -rp "$(t MP_UI_PRESS_ENTER)"
                ;;
            5)
                echo "$(t MP_SYS_BACK)"
                return 0   # если это функция
                # или break  # если это loop внутри скрипта
                ;;         
            *)
                echo "$(t MP_UI_INVALID_OPTION)"
                sleep 1
                ;;
        esac
    done
}
