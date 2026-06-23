#!/usr/bin/env bash
# modules/system/modules/man/doctor.sh

man_doctor() {
    echo "Remedia System Man module"
    echo
    
#    echo "[TRACE] doctor pid=$$ caller=$(caller 0)"

    local missing=0

    for page in users-home-restore; do
        if ! man -w "$page" >/dev/null 2>&1; then
            echo "[BROKEN] missing: $page"
            missing=$((missing + 1))
        fi
    done

    if (( missing == 0 )); then
        echo "[DOCTOR] OK"
    else       
        echo "[DOCTOR] issues: $missing"
        return 1
    fi
}
