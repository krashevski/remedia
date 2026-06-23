#!/usr/bin/env bash
# modules/mediasystem/modules/doctor/doctor.sh

mediasystem_health_check() {
    echo
    echo -e " ${COLOR_BOLD} REMEDIA MEDIASYSTEM DOCTOR ${COLOR_RESET}"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local FAIL=0
    local WARN=0

    # 1. runtime isolation
    if env -i bash -c 'exit 0' 2>/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} runtime isolation"
    else
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} runtime isolation"
        ((FAIL++))
    fi

    # 2. core binaries (SAFE)
    for bin in apt ffmpeg; do
        if command -v "$bin" >/dev/null; then
            echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $bin"
        else
            echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $bin missing"
            ((WARN++))
        fi
    done

    # 3. GPU subsystem (STANDARD)
    if command -v nvidia-smi >/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} NVIDIA driver (nvidia-smi)"
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} NVIDIA not detected"
        ((WARN++))
    fi

    if command -v nvcc >/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} CUDA toolkit"
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} CUDA not installed"
        ((WARN++))
    fi

    if command -v glxinfo >/dev/null; then
        RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" || true)
        if [[ -n "$RENDERER" ]]; then
            echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} OpenGL: $RENDERER"
        else
            echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} OpenGL broken (no renderer)"
            ((FAIL++))
        fi
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} glxinfo missing"
        ((WARN++))
    fi

    # 5. Snap subsystem (FULL)
    if command -v snap >/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} snap"
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} snap missing"
        ((WARN++))
    fi

    # 6. Apps layer (Shotcut / OBS)
    # Shotcut (system OR flatpak)
    if command -v shotcut >/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} shotcut (system)"
    elif sudo -u "$RUN_USER" flatpak list | grep -q "org.shotcut.Shotcut"; then
         echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} shotcut (flatpak)"
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} shotcut missing"
        ((WARN++))
    fi

    if command -v obs >/dev/null || command -v obs-studio >/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} OBS"
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} OBS missing"
        ((WARN++))
    fi

    # 7. Postinstall GPU check (ключевой момент)    
    # NVENC check (robust)
    NVENC_LIST=$(ffmpeg -encoders 2>/dev/null | grep -E "nvenc" || true)

    if [[ -n "$NVENC_LIST" ]]; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} NVENC:"
        echo "$NVENC_LIST" | sed 's/^/   /'
    else
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} ffmpeg without NVENC"
        ((WARN++))
    fi

    # 8. Remedia runtime vars
    if [[ -n "${REMEDIA_ROOT:-}" ]]; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} REMEDIA_ROOT"
    else
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} REMEDIA_ROOT missing"
        ((FAIL++))
    fi

    # 9. User context
#    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} USER: ${RUN_USER:-$(whoami)}"
#    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} HOME: ${HOME:-unknown}"

    # 10. Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local TOTAL=$((FAIL + WARN))
    local SCORE=100

    if (( TOTAL > 0 )); then
        SCORE=$((100 - FAIL*30 - WARN*10))
        (( SCORE < 0 )) && SCORE=0
    fi

    if (( FAIL == 0 )); then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} mediasystem healthy"
    else
        echo -e "${COLOR_RED}[BROKEN]${COLOR_RESET} mediasystem issues detected"
    fi

    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} FAIL: $FAIL  WARN: $WARN"
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} REMEDIA MEDIASYSTEM HEALTH: ${SCORE}%"
    
    REMEDIA_FAIL=$FAIL
    REMEDIA_WARN=$WARN

    return $FAIL
}
