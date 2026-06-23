#!/usr/bin/env bash
# modules/system/modules/home/doctor.sh

home_doctor() {
    local user="${1:-}"

    [[ -z "$user" ]] && {
        echo "Remedia System Home module"
        echo
        echo "[ERROR] user required"
        echo "Usage:" 
        echo "  remedia system home doctor USER"
        return 1
    }

    local path="/home/$user"
    echo "Remedia System Home module"
    echo
    echo "[HOME] [DOCTOR] checking $user"

    # user exists
    if ! id "$user" &>/dev/null; then
        echo "[DOCTOR] [BROKEN] user does not exist"
        return 2
    fi

    # directory exists
    if [[ ! -d "$path" ]]; then
        echo "[DOCTOR] [BROKEN] home directory missing"
        return 3
    fi

    local uid
    uid="$(id -u "$user")"

    local owner
    owner="$(stat -c %u "$path")"

    if [[ "$uid" != "$owner" ]]; then
        echo "[DOCTOR] [BROKEN] owner mismatch (uid=$uid owner=$owner)"
        return 4
    fi
    echo "[DOCTOR] [OK] home for $user is healthy"
    return 0
}
