#!/usr/bin/env bash
# modules/backupkit/modules/init/init_backupkit.sh 

init_backupkit_layout() {
    local dirs=(
        "$BACKUP_ROOT"
        "$BACKUP_ROOT/user_data"
        "$BACKUP_ROOT/firefox"
    )

    for d in "${dirs[@]}"; do
        mkdir -p "$d"
        chown root:backupkit "$d"
        chmod 2775 "$d"
    done
}

init_backupkit() {
    echo "Remedia Backupkit Home module"
    echo
    [[ -d "$USER_ROOT" ]] || init_user_fs
    log_info "Initializing backupkit FS"
    
    init_backupkit_layout
    
    init_user_registry
    
    log_info "User storage ready"
    log_info "Done"
}
