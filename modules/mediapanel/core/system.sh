#!/usr/bin/env bash
# mediapanel/core/system.sh

: "${REMEDIA_LIB:?missing REMEDIA_LIB}"
: "${FAST_STORAGE:?missing FAST_STORAGE}"
: "${SLOW_STORAGE:?missing SLOW_STORAGE}"
if [[ -z "${BACKUP_STORAGE:-}" ]]; then
    echo "[FATAL] BACKUP_STORAGE is empty"
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
        echo -e "                 ${COLOR_BOLD}${COLOR_CYAN}SYSTEM STATUS${RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
        echo
        echo " GPU:      $GPU"
        case "$NVENC" in
            YES)
                if [[ "$NVENC" == "YES" ]]; then
                    echo -e " NVENC:    ${COLOR_GREEN}AVAILABLE (h264/hevc)${RESET}"
                fi
                ;;
            NO_FFMPEG)
                echo -e " NVENC:    ${COLOR_YELLOW}FFmpeg missing NVENC${RESET}"
                ;;
            NO_GPU)
                echo -e " NVENC:    ${COLOR_RED}No NVIDIA GPU${RESET}"
                ;;
            *)
                echo -e " NVENC:    ${COLOR_RED}UNKNOWN${RESET}"
                ;;
        esac 
        echo
        echo " Projects: $projects_count"
        if [[ -n "$active" ]]; then
            echo -e " Active project: ${COLOR_GREEN}${active}${RESET}"
        else
            echo -e " Active project: ${COLOR_RED}none${RESET}"
        fi
        echo
        df -h "$FAST_STORAGE" "$SLOW_STORAGE" "$BACKUP_STORAGE" 2>/dev/null
        echo
        phone_status
        echo
        echo -e "${COLOR_BOLD}MENU:${RESET}"
        echo
        echo " 1) Refresh"
        echo " 2) Show system log"
        echo " 3) Show disk usage"
        echo " 4) Show GPU info"
        echo
        echo -e " ${COLOR_CYAN}5) Back${RESET}"
        echo
        read -rp "Choice [1-5]: " choice

        case "$choice" in
            1)
                continue
                ;;

            2)
               while true; do
                   clear
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                   echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}SYSTEM LOG${RESET}"
                   echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                   echo
                   echo "1) Last 50 lines"
                   echo "2) Last 200 lines"
                   echo "3) Follow (live)"
                   echo
                   echo -e "${COLOR_CYAN}4) Back${RESET}"
                   echo

                   read -rp "log [1-4]> " lchoice

                   case "$lchoice" in
                       1)
                          tail -n 50 "$LOG_FILE"
                          read -rp "Enter..."
                          ;;
                       2)
                          tail -n 200 "$LOG_FILE"
                          read -rp "Enter..."
                          ;;
                       3)
                          echo "Press Ctrl+C to stop"
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
                echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}DISK DETAILS${RESET}"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo
                echo -e "${COLOR_BOLD}Storage usage:${RESET}"
                echo
                
                printf "%-20s %s\n" "FAST_STORAGE:" "$(get_dir_size_cached "$FAST_STORAGE" || echo 'ERR')"
                printf "%-20s %s\n" "SLOW_STORAGE:" "$(get_dir_size_cached "$SLOW_STORAGE" || echo 'ERR')"
                printf "%-20s %s\n" "BACKUP_STORAGE:" "$(get_dir_size_cached "$BACKUP_STORAGE" || echo 'ERR')"
                printf "%-20s %s\n" "PROJECT_DIR:" "$(get_dir_size_cached "$PROJECT_DIR" || echo 'ERR')"
                
                echo
                echo -e "${COLOR_BOLD}Paths:${RESET}"
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
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}GPU INFO${RESET}"
                echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${RESET}"
                echo
                lspci | grep -i vga
                echo
                ffmpeg -encoders 2>/dev/null | grep nvenc || echo "NVENC not available"
                echo
                read -rp "Press Enter..."
                ;;
            5)
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
