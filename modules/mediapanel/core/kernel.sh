#!/usr/bin/env bash
# mediapanel/core/kernel.sh

require() {
    declare -F "$1" >/dev/null || {
        echo "[FATAL] missing dependency: $1"
        return 1
    }
}

ensure_core() {
    require detect_gpu
    require detect_nvenc
    require log_system
}


