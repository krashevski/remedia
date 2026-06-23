#!/usr/bin/env bash
# core/kernel.sh

# -------------------------
# HELPERS
# -------------------------
ensure_dir() {
    local dir="$1"

    [[ -n "$dir" ]] || {
        echo "[FATAL] ensure_dir: empty path"
        return 1
    }

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || {
            echo "[ERROR] mkdir failed: $dir"
            return 1
        }
    fi
}

# GPU detection
detect_gpu() {
    if lspci | grep -qi nvidia; then
        echo "NVIDIA"
    else
        echo "CPU"
    fi
}

detect_nvenc() {
    if ffmpeg -encoders 2>/dev/null | grep -q nvenc; then
        echo "YES"
    else
        echo "NO"
    fi
}


log_system() {
    : "${LOG_DIR:=${REMEDIA_VAR:-$HOME/.remedia}/logs}"

    mkdir -p "$LOG_DIR"
    echo "[$(date '+%F %T')] $*" >> "$LOG_DIR/system.log"
}

# basic phone_status
phone_status_base() {
    echo "Phone subsystem: available"
}

