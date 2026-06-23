#!/usr/bin/env bash
# backupkit/firefox.sh — Firefox backup module (RAW + HUMAN export)

########################################
# CONFIG CHECKS
########################################

: "${FIREFOX_BACKUP_ROOT:?FIREFOX_BACKUP_ROOT is required}"
# : "${FIREFOX_BOOKMARKS_ROOT:?FIREFOX_BOOKMARKS_ROOT is required}"
FIREFOX_BOOKMARKS_ROOT="${FIREFOX_BOOKMARKS_ROOT:-$HOME/.local/share/remedia/firefox/bookmarks}"

########################################
# RESOLVE FIREFOX PROFILE ROOT
########################################

resolve_FIREFOX_BACKUP_ROOT() {
    if [[ -d "$HOME/snap/firefox/common/.mozilla/firefox" ]]; then
        echo "$HOME/snap/firefox/common/.mozilla/firefox"
    elif [[ -d "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" ]]; then
        echo "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    elif [[ -d "$HOME/.mozilla/firefox" ]]; then
        echo "$HOME/.mozilla/firefox"
    else
        echo "[ERROR] Firefox profiles not found" >&2
        return 1
    fi
}

########################################
# CHECK RUNNING FIREFOX
########################################

is_firefox_running() {
    pgrep -x firefox >/dev/null 2>&1
}

warn_if_running() {
    if is_firefox_running; then
        echo "[WARN] Firefox is running — backup may be inconsistent"
    fi
}

########################################
# EXPORT BOOKMARKS TO HTML (HUMAN)
########################################

export_bookmarks_html_sqlite() {
    local profile="$1"
    local dst="$2"

    local db="$profile/places.sqlite"
    local out="$dst/bookmarks.html"

    [[ -f "$db" ]] || return 0

    if ! command -v sqlite3 >/dev/null 2>&1; then
        echo "[WARN] sqlite3 not found, skipping HTML export"
        return 0
    fi

    # простая читаемая HTML таблица
    sqlite3 "$db" <<'EOF' > "$out"
.headers off
.mode html
SELECT 
    b.title AS Title,
    p.url AS URL
FROM moz_bookmarks b
LEFT JOIN moz_places p ON b.fk = p.id
WHERE p.url IS NOT NULL
ORDER BY b.id;
EOF

    echo "[INFO] Exported bookmarks HTML → $out"
}

bookmarks_open() {
    local path="${FIREFOX_BOOKMARKS_ROOT:-$HOME/.local/share/remedia/firefox/bookmarks}"
    xdg-open "$path" >/dev/null 2>&1 &
}

########################################
# BACKUP SINGLE PROFILE
########################################

backup_profile() {
    local profile="$1"
    local name
    name="$(basename "$profile")"

    local dst="$FIREFOX_BACKUP_ROOT/$name"
    mkdir -p "$dst"

    echo "[INFO] Backing up profile: $name"

    # RAW
    [[ -f "$profile/places.sqlite" ]] && cp -a "$profile/places.sqlite" "$dst/"
    [[ -d "$profile/bookmarkbackups" ]] && rsync -a "$profile/bookmarkbackups/" "$dst/bookmarkbackups/"
    [[ -d "$profile/extensions" ]] && rsync -a "$profile/extensions/" "$dst/extensions/"

    # HUMAN
    local human_dst="$FIREFOX_BOOKMARKS_ROOT/$name"
    mkdir -p "$human_dst"

    export_bookmarks_html_sqlite "$profile" "$human_dst"

    echo "[INFO] Profile done: $name"
}

########################################
# MAIN BACKUP FUNCTION
########################################

backup_firefox() {
    warn_if_running

    local root
    root="$(resolve_FIREFOX_BACKUP_ROOT)" || return 1

    echo "[INFO] Firefox root: $root"
    echo "[INFO] RAW backup → $FIREFOX_BACKUP_ROOT"
    echo "[INFO] HUMAN backup → $FIREFOX_BOOKMARKS_ROOT"

    mkdir -p "$FIREFOX_BACKUP_ROOT"
    mkdir -p "$FIREFOX_BOOKMARKS_ROOT"

    shopt -s nullglob

    local profile
    for profile in "$root"/*.default* "$root"/*.default-release*; do
        [[ -d "$profile" ]] || continue
        backup_profile "$profile"
    done

    shopt -u nullglob

    echo "[INFO] Firefox backup complete"
}

restore_firefox() {
    : "${FIREFOX_BACKUP_ROOT:?FIREFOX_BACKUP_ROOT is required}"
    : "${FIREFOX_BOOKMARKS_ROOT:?FIREFOX_BOOKMARKS_ROOT is required}"

    local root
    root="$(resolve_FIREFOX_BACKUP_ROOT)" || return 1

    echo "[INFO] Restore Firefox FROM: $FIREFOX_BACKUP_ROOT"
    echo "[INFO] Target Firefox root: $root"

    if [[ ! -d "$FIREFOX_BACKUP_ROOT" ]]; then
        echo "[ERROR] Backup not found: $FIREFOX_BACKUP_ROOT"
        return 1
    fi

    ########################################
    # SAFETY CHECK
    ########################################

    if pgrep -x firefox >/dev/null 2>&1; then
        echo "[ERROR] Firefox is running. Close it first."
        return 1
    fi

    ########################################
    # RESTORE PROFILES
    ########################################

    shopt -s nullglob

    local backup_profile
    for backup_profile in "$FIREFOX_BACKUP_ROOT"/*; do
        [[ -d "$backup_profile" ]] || continue

        local prof_name
        prof_name="$(basename "$backup_profile")"

        local target="$root/$prof_name"

        echo "[INFO] Restoring profile: $prof_name"

        mkdir -p "$target"

        ####################################
        # CORE RESTORE
        ####################################

        [[ -f "$backup_profile/places.sqlite" ]] && \
            cp -a "$backup_profile/places.sqlite" "$target/"

        [[ -d "$backup_profile/bookmarkbackups" ]] && \
            rsync -a "$backup_profile/bookmarkbackups/" "$target/bookmarkbackups/"

        [[ -d "$backup_profile/extensions" ]] && \
            rsync -a "$backup_profile/extensions/" "$target/extensions/"

        ####################################
        # OPTIONAL FILES
        ####################################

        [[ -f "$backup_profile/prefs.js" ]] && \
            cp -a "$backup_profile/prefs.js" "$target/"

        echo "[INFO] Profile restored: $prof_name"
    done

    shopt -u nullglob

    ########################################
    # RESTORE profiles.ini (CRITICAL)
    ########################################

    local ini="$root/profiles.ini"
    local backup_ini="$FIREFOX_BACKUP_ROOT/profiles.ini"

    if [[ -f "$backup_ini" ]]; then
        cp -a "$backup_ini" "$ini"
        echo "[INFO] profiles.ini restored"
    else
        echo "[WARN] profiles.ini not found in backup — Firefox may recreate it"
    fi

    ########################################
    # FIX PERMISSIONS
    ########################################

    chown -R "$USER":"$USER" "$root" 2>/dev/null || true

    echo "[INFO] Firefox restore complete"
}
