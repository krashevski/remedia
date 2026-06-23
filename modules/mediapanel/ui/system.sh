#!/usr/bin/env bash
# mediapanel/core/system.sh

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

system_status() {
    while true; do
        active="$(get_active_project)"
#        LOG_FILE="$PROJECT_DIR/$active/.log"
        LOG_FILE="$(ensure_log_file "$active" || true)"
        echo
        clear        
        
        local GPU NVENC projects_count     
        
        GPU="$(get_gpu_cached)"
        NVENC="$(get_nvenc_cached)"       
   

        local projects_count=0
        [[ -d "$PROJECT_DIR" ]] && \
            projects_count=$(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                 ${COLOR_BOLD}${COLOR_CYAN}SYSTEM STATUS${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
        echo " GPU:      $GPU"
        case "$NVENC" in
            YES)
                if [[ "$NVENC" == "YES" ]]; then
                    echo -e " NVENC:    ${COLOR_GREEN}AVAILABLE (h264/hevc)${COLOR_RESET}"
                fi
                ;;
            NO_FFMPEG)
                echo -e " NVENC:    ${COLOR_YELLOW}FFmpeg missing NVENC${COLOR_RESET}"
                ;;
            NO_GPU)
                echo -e " NVENC:    ${COLOR_RED}No NVIDIA GPU${COLOR_RESET}"
                ;;
            *)
                echo -e " NVENC:    ${COLOR_RED}UNKNOWN${COLOR_RESET}"
                ;;
        esac 
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
        echo -e "${COLOR_BOLD}MENU:${COLOR_RESET}"
        echo
        echo " 1) Refresh"
        echo " 2) Show system log"
        echo " 3) Show disk usage"
        echo " 4) Show GPU info"
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
                ffmpeg -encoders 2>/dev/null | grep nvenc || echo "NVENC not available"
                echo
                read -rp "Press Enter..."
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
