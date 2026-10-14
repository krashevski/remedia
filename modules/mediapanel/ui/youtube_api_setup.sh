#!/usr/bin/env bash
# MediaPanel YouTube OAuth setup. Source from ui/system.sh.
# Depends on existing youtube_api_python() and mediapanel_install_youtube_api().

mediapanel_youtube_config_dir() {
    printf '%s\n' "${REMEDIA_YOUTUBE_CONFIG_DIR:-$HOME/.config/remedia/youtube}"
}

# No network traffic, no token refresh, no secrets printed.
mediapanel_youtube_probe() {
    local py cfg
    py="$(youtube_api_python)"
    cfg="$(mediapanel_youtube_config_dir)"
    YT_DEPS=missing YT_CLIENT=missing YT_TOKEN=missing

    if [[ -x "$py" ]] && "$py" -c 'import googleapiclient, google_auth_oauthlib, google_auth_httplib2, google.oauth2.credentials' >/dev/null 2>&1; then
        YT_DEPS=installed
    fi
    if [[ -f "$cfg/client_secrets.json" ]]; then
        if command -v python3 >/dev/null 2>&1 && python3 - "$cfg/client_secrets.json" <<'PY' >/dev/null 2>&1
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: data=json.load(f)
app=data.get('installed',{})
assert isinstance(app,dict) and app.get('client_id') and app.get('client_secret') and app.get('auth_uri') and app.get('token_uri')
PY
        then YT_CLIENT=valid; else YT_CLIENT=invalid; fi
    fi
    if [[ -f "$cfg/token.json" ]]; then
        if command -v python3 >/dev/null 2>&1 && python3 - "$cfg/token.json" <<'PY' >/dev/null 2>&1
import json,sys
with open(sys.argv[1],encoding='utf-8') as f: data=json.load(f)
assert isinstance(data,dict) and data.get('token') and data.get('client_id')
PY
        then YT_TOKEN=present_unverified; else YT_TOKEN=invalid; fi
    fi
}

mediapanel_youtube_api_status() {
    mediapanel_youtube_probe
    echo 'YouTube API:'
    echo "   Python dependencies: $YT_DEPS"
    echo "   OAuth client config: $YT_CLIENT"
    case "$YT_TOKEN" in
        present_unverified) echo '   OAuth token: present (validity not checked)' ;;
        *) echo "   OAuth token: $YT_TOKEN" ;;
    esac
    echo '   Setup: 8) YouTube API Setup'
}

mediapanel_youtube_next_step() {
    if [[ "$YT_DEPS" != installed ]]; then
        echo 'Next step: 1) Install Python dependencies'
    elif [[ "$YT_CLIENT" != valid ]]; then
        echo 'Next step: 2) Install client_secrets.json'
    elif [[ "$YT_TOKEN" != present_unverified ]]; then
        echo 'Next step: 3) Authorize YouTube account'
    else
        echo 'Next step: 4) Check / refresh token, then 5) Test connection'
    fi
}

mediapanel_youtube_instructions() {
    cat <<'INSTRUCTIONS'
====================================================
            YOUTUBE API SETUP INSTRUCTIONS
====================================================
1. Visit https://console.cloud.google.com/
   Create or select your Google Cloud project.
2. Enable "YouTube Data API v3" in API Library:
   https://console.cloud.google.com/apis/library
3. Configure Google Auth Platform consent screen.
   For an External app in Testing, add your account as test user.
   Testing refresh tokens may expire after 7 days.
4. Create OAuth Client ID of type "Desktop app":
   https://console.cloud.google.com/auth/clients
5. Download its JSON credentials file.
6. Back in MediaPanel select "Install client_secrets.json".
7. Select "Authorize YouTube account" to open your browser.
8. Check token, then test API connection (read-only).

Notes:
- Never commit client_secrets.json or token.json to Git.
- OAuth credentials belong to each user, not the .deb package.
- API readiness requires an actual authorization / API check.
====================================================
INSTRUCTIONS
}

mediapanel_youtube_install_credentials() {
    local src cfg dst tmp confirm
    cfg="$(mediapanel_youtube_config_dir)"
    dst="$cfg/client_secrets.json"
    echo 'Enter path to downloaded Desktop OAuth JSON file:'
    read -r -p 'File: ' src || return 0
    [[ -n "$src" && -f "$src" ]] || { echo '[ERROR] File not found.'; return 1; }
    python3 - "$src" <<'PY' || { echo '[ERROR] Invalid Desktop OAuth client JSON.'; return 1; }
import json,sys
with open(sys.argv[1], encoding='utf-8') as f: d=json.load(f)
a=d.get('installed', {})
assert isinstance(a,dict) and all(a.get(k) for k in ('client_id','client_secret','auth_uri','token_uri'))
PY
    if [[ -e "$dst" ]]; then
        read -r -p 'Existing credentials found. Replace? [y/N]: ' confirm || return 0
        [[ "$confirm" =~ ^[YyДд]$ ]] || { echo 'Cancelled.'; return 0; }
    fi
    (umask 077; mkdir -p -- "$cfg") || return 1
    tmp="$(mktemp "$cfg/.client_secrets.XXXXXXXX")" || return 1
    if ! cat -- "$src" > "$tmp" || ! chmod 600 "$tmp" || ! mv -f -- "$tmp" "$dst"; then
        rm -f -- "$tmp"
        echo '[ERROR] Cannot install credentials.'
        return 1
    fi
    echo '[OK] OAuth credentials installed (mode 600).'
    if [[ -f "$cfg/token.json" ]]; then
        echo '[INFO] Existing OAuth token kept. Reauthorize if it belongs to another OAuth client.'
    fi
}

# Worker is loaded from package directory and runs under the user venv.
mediapanel_youtube_worker() {
    local py worker
    py="$(youtube_api_python)"
    worker="${REMEDIA_YOUTUBE_WORKER:-${REMEDIA_LIB:-/usr/lib/remedia}/modules/mediapanel/ui/youtube_oauth.py}"
    [[ -x "$py" ]] || { echo '[ERROR] Install Python dependencies first.'; return 1; }
    [[ -f "$worker" ]] || { echo "[ERROR] Missing worker: $worker"; return 1; }
    "$py" "$worker" "$1" "$(mediapanel_youtube_config_dir)"
}

mediapanel_youtube_setup_menu() {
    local choice
    while true; do
        mediapanel_youtube_probe
        echo
        echo '===================================================='
        echo '                  YOUTUBE API SETUP'
        echo '===================================================='
        echo "Python dependencies: $YT_DEPS"
        echo "OAuth client config: $YT_CLIENT"
        echo "OAuth token: $YT_TOKEN"
        mediapanel_youtube_next_step
        echo
        echo '1) Install Python dependencies'
        echo '2) Install client_secrets.json'
        echo '3) Authorize YouTube account'
        echo '4) Check / refresh OAuth token'
        echo '5) Test YouTube API connection (read-only)'
        echo '6) Show Google Cloud setup instructions'
        echo '0) Back'
        read -r -p 'Choice: ' choice || return 0
        case "$choice" in
            1) mediapanel_install_youtube_api || true ;;
            2) mediapanel_youtube_install_credentials || true ;;
            3) mediapanel_youtube_worker authorize || true ;;
            4) mediapanel_youtube_worker check || true ;;
            5) mediapanel_youtube_worker test || true ;;
            6) mediapanel_youtube_instructions ;;
            0) return 0 ;;
            *) echo 'Invalid option.' ;;
        esac
        read -r -p 'Press Enter to continue...' _ || return 0
    done
}
