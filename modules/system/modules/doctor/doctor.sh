#!/usr/bin/env bash
# /modules/system/modules/doctor/doctor.sh

system_diagnostics() {
    echo
    echo -e "   ${COLOR_BOLD} REMEDIA SYSTEM DOCTOR ${COLOR_RESET}"
    echo 
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local FAIL=0
    local WARN=0

    # 1. runtime isolation
    if env -i bash -c 'exit 0' 2>/dev/null; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} runtime isolation (env -i)"
    else
        echo -e "${COLOR_RED}[FAIL]${COLOR_RESET} runtime isolation"
    fi

    # 2. paths
    [[ -n "${PROJECT_DIR:-}" && -d "$PROJECT_DIR" ]] \
        && echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} PROJECT_DIR: $PROJECT_DIR" \
        || { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} PROJECT_DIR missing"; ((WARN++)); }

    [[ -n "${BACKUP_STORAGE:-}" && -d "$BACKUP_STORAGE" ]] \
        && echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} BACKUP_STORAGE: $BACKUP_STORAGE" \
        || { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} BACKUP_STORAGE missing"; ((WARN++)); }
        
   if ! command -v ffmpeg >/dev/null; then
        echo "${COLOR_YELLOW}[WARN]${COLOR_RESET} ffmpeg not installed"
    else
        echo "${COLOR_GREEN}[OK]${COLOR_RESET} ffmpeg"
    fi
    
    # 3. user context
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} USER: ${RUN_USER:-$(whoami)}"
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} HOME: ${HOME:-unknown}"

    # 4. version (если есть)
    if [[ -n "${REMEDIA_VERSION:-}" ]]; then
        echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} VERSION: $REMEDIA_VERSION"
    else
        echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} VERSION: unknown"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local TOTAL=$((FAIL + WARN))
    local SCORE=100

    if (( TOTAL > 0 )); then
        SCORE=$((100 - FAIL*30 - WARN*10))
        (( SCORE < 0 )) && SCORE=0
    fi
    
    if (( FAIL == 0 && WARN == 0 )); then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} remedia system healthy"
    elif (( FAIL == 0 )); then
        echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} remedia system degraded"
    else
        echo -e "${COLOR_RED}[BROKEN]${COLOR_RESET} remedia system issues detected"
    fi

    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} FAIL: $FAIL  WARN: $WARN"
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} REMEDIA SYSTEM HEALTH: ${SCORE}%"
    
    REMEDIA_FAIL=$FAIL
    REMEDIA_WARN=$WARN

    return $FAIL
}
