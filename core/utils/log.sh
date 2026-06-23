#!/usr/bin/env bash
# core/log.sh - только дефолты

: "${REMEDIA_LOG_LEVEL:=INFO}"
RUN_USER_HOME=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
: "${LOG_DIR:=$RUN_USER_HOME/.remedia/logs}"
: "${LOG_FILE:=$LOG_DIR/remedia.log}"
: "${LOG_MAX_SIZE:=1048576}"   # 1MB
: "${LOG_MAX_FILES:=5}"

declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

log_rotate() {
    [[ -f "$LOG_FILE" ]] || return

    local size
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)

    if (( size < LOG_MAX_SIZE )); then
        return
    fi

    echo "[LOG] rotating..."

    # удалить самый старый
    [[ -f "$LOG_FILE.$LOG_MAX_FILES" ]] && rm -f "$LOG_FILE.$LOG_MAX_FILES"

    # сдвиг файлов
    for ((i=LOG_MAX_FILES-1; i>=1; i--)); do
        if [[ -f "$LOG_FILE.$i" ]]; then
            mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
        fi
    done

    # текущий → .1
    mv "$LOG_FILE" "$LOG_FILE.1"

    # создать новый
    : > "$LOG_FILE"
}

log_write() {
    local level="$1"
    shift
    local msg="$*"
    
    # QUIET режим
    if [[ "${REMEDIA_QUIET:-0}" -eq 1 ]]; then
        case "$level" in
            INFO) return ;;   # скрываем INFO
        esac
    fi

    local current="${LOG_LEVELS[$REMEDIA_LOG_LEVEL]:-1}"
    local incoming="${LOG_LEVELS[$level]:-1}"

    (( incoming < current )) && return 0

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$LOG_DIR"

    log_rotate

    echo "[$ts] [$level] $msg" >> "$LOG_FILE"

    # опционально: вывод в консоль   
    local color=""
    case "$level" in
        DEBUG) color="$COLOR_BLUE" ;;
        INFO)  color="$COLOR_CYAN" ;;
        WARN)  color="$COLOR_YELLOW" ;;
        ERROR) color="$COLOR_RED" ;;
        OK)    color="$COLOR_GREEN" ;;
        BOLD)  color="$COLOR_BOLD" ;;
    esac

    if [[ "$level" == "DEBUG" ]]; then
        echo "${color}[$level]${COLOR_RESET} $msg" >&2
    else
        echo "${color}[$level]${COLOR_RESET} $msg"
    fi
}

log_debug() { log_write DEBUG "$@"; }
log_info()  { log_write INFO  "$@"; }
log_warn()  { log_write WARN  "$@"; }
log_error() { log_write ERROR "$@"; }
log_ok()    { log_write OK "$@"; }

log_init() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}
