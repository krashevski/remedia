#!/usr/bin/env bash
# /modules/system/modules/dpkg/doctor.sh

spinner() {
    local pid=$!
    local spin='-\|/'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r[INFO] checking updates... %s" "${spin:$i:1}"
        sleep 0.1
    done

    printf "\r"
}

# --- APT / DPKG HEALTH ---
dpkg_doctor() {
   echo
    echo -e "   ${COLOR_BOLD} SYSTEM DPKG DOCTOR ${COLOR_RESET}"
    echo 
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # audit
    echo "[STEP] audit..."
    if dpkg --audit | grep -q .; then
        echo -e "${COLOR_RED}[ISSUE]${COLOR_RESET} dpkg reports broken packages"

        if [[ "${REMEDIA_AUTO_HEAL:-0}" == "1" ]]; then
            echo "[ACTION] fixing dpkg..."
            sudo dpkg --configure -a
        else
            echo "[HINT] run: sudo dpkg --configure -a"
        fi
    else
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} dpkg state clean"
    fi

    # broken deps
    echo "[STEP] checking broken deps..."
    if ! sudo apt -f install -s >/dev/null 2>&1; then
        echo -e "${COLOR_RED}[ISSUE]${COLOR_RESET} broken dependencies detected"

        if [[ "${REMEDIA_AUTO_HEAL:-0}" == "1" ]]; then
            echo "[ACTION] fixing dependencies..."
            sudo apt -f install -y
        else
            echo "[HINT] run: sudo apt -f install"
        fi
    else
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} dependencies OK"
    fi
    
    # checking zombie
    if ps aux | grep -E "\[apt-get\].*defunct" | grep -qv grep; then
        echo "[WARN] zombie apt process detected"
        echo "[ACTION] remedia system dpkg heal"
    fi

    # locks
    echo "[STEP] checking locks..."
    has_lock=false

    [[ -f /var/lib/dpkg/lock || -f /var/lib/dpkg/lock-frontend ]] && has_lock=true

    if $has_lock; then
        if pgrep -x apt >/dev/null || pgrep -x dpkg >/dev/null; then
            echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} apt/dpkg is running"
        else
            # 🔥 ДОП. ПРОВЕРКА
            if lsof /var/lib/dpkg/lock >/dev/null 2>&1; then
                echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} lock in use"
            else
                echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} dpkg lock file present (not in use)"
            fi
        fi
    else
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} no dpkg locks"
    fi
    
    # checking for updates       
    echo "[STEP] checking updates..."

    LANG=C apt list --upgradable > "$SYSTEM_VAR/remedia_upgrades" 2>/dev/null &
    spinner

    UPGRADABLE=$(grep -v Listing "$SYSTEM_VAR/remedia_upgrades" | wc -l)
    
    if [[ "$UPGRADABLE" -eq 0 ]]; then
        level="${COLOR_GREEN}[OK]"
    elif [[ "$UPGRADABLE" -le 10 ]]; then
        level="${COLOR_BLUE}[INFO]"
    elif [[ "$UPGRADABLE" -le 100 ]]; then
        level="${COLOR_YELLOW}[WARN]"
    else
        level="${COLOR_RED}[CRITICAL]"
    fi
    
    echo "[STEP] checking updates... done"  
    if [[ "$UPGRADABLE" -eq 0 ]]; then
        echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} system up to date"
    else
    # ACTION только если есть что делать
#    if [[ "$UPGRADABLE" -gt 0 ]]; then
        echo        
        echo "[INFO] last update: $(stat -c %y /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo unknown)"
        echo
        echo -e "${level}${COLOR_RESET} $UPGRADABLE packages can be upgraded"
        echo "[ACTION] safe upgrade (no removals):"
        echo "         remedia system dpkg upgrade"

        echo "[ACTION] full upgrade (recommended, may change dependencies):"
        echo "         remedia system dpkg full-upgrade"
    fi
    
    echo
    echo "[INFO] showing first 5 of $UPGRADABLE packages"
    echo "[PREVIEW] upgradable packages:"
    sed '1d' "$SYSTEM_VAR/remedia_upgrades" | head -5
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[SUMMARY] dpkg check complete"
}
