#!/usr/bin/env bash
# modules/system/modules/home/policy.sh

home_policy_validate() {
    local user="$1"
    local path="$2"

    # ❌ запрещено root
    [[ "$user" == "root" ]] && {
        echo "[POLICY] root is forbidden"
        return 1
    }

    # ❌ путь должен быть /home/*
    [[ "$path" != /home/* ]] && {
        echo "[POLICY] invalid path: $path"
        return 1
    }

    # ❌ пользователь должен существовать
    id "$user" &>/dev/null || {
        echo "[POLICY] user does not exist"
        return 1
    }

    return 0
}
