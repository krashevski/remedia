#!/usr/bin/env bash
# modules/backupkit/modules/registry/registry.sh 

# в начале файла
source "$REMEDIA_LIB/modules/backupkit/core/env.sh"

init_user_registry() {
    local reg="$REGISTRY_DIR"

    chown root:backupkit "$reg"
    chmod 2775 "$reg"

    local db="$reg/users.db"

    touch "$db" || return 1
    chown root:backupkit "$db"
    chmod 664 "$db"
}

registry_add_user() {
    local user="$1"

    init_user_registry || {
        echo "[ERROR] failed to init registry"
        return 1
    }

    local db="$REGISTRY_DIR/users.db"

    grep -q "^$user:" "$db" 2>/dev/null && return 0
    
    (
        flock -x 200
        grep -q "^$user:" "$db" || echo "$user:active" >> "$db"
    ) 200>"$db.lock"
}

registry_is_active() {
    local user="$1"
    grep -q "^$user:active" "$REGISTRY_DIR/users.db"
}

registry_has_user() {
    local user="$1"
    if ! registry_is_active "$BK_USER"; then
        echo "[ERROR] user not active"
        exit 1
    fi
    grep -q "^$user:" "$REGISTRY_DIR/users.db"
}

registry_status() {
    local user="$1"
    grep "^$user:" "$REGISTRY_DIR/users.db" | cut -d: -f2
}

registry_list_users() {
    local db="$REGISTRY_DIR/users.db"

    [[ -f "$db" ]] || {
        echo "[INFO] no users registered"
        return 0
    }

    echo "Registered users:"
    echo

    while IFS=: read -r user status; do
        printf "  - %s (%s)\n" "$user" "$status"
    done < "$db"
}

registry_list_users_numbered() {
    echo "Remedia Backupkit User module"
    echo
    local db="$REGISTRY_DIR/users.db"
    
    [[ -f "$db" ]] || {
        echo "[INFO] no users registered"
        return 0
    }
    
    echo "Registered users:"

    local i=1
    while IFS=: read -r user status; do
        printf "  %d) %s (%s)\n" "$i" "$user" "$status"
        ((i++))
    done < "$db"
}

registry_enable_user() {
    local user="$1"
    local db="$REGISTRY_DIR/users.db"

    sed -i "s/^$user:disabled/$user:active/" "$db"
}

registry_disable_user() {
    local user="$1"
    local db="$REGISTRY_DIR/users.db"

    sed -i "s/^$user:active/$user:disabled/" "$db"
}

registry_set_status() {
    local user="$1"
    local new_status="$2"
    local db="$REGISTRY_DIR/users.db"

    sed -i "s/^$user:.*/$user:$new_status/" "$db"
}

registry_remove_user() {
    local user="$1"
    local db="$REGISTRY_DIR/users.db"

    grep -v "^$user:" "$db" > "$db.tmp" && mv "$db.tmp" "$db"
}




