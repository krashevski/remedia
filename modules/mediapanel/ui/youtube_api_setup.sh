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

# Translate display labels only; probe state values remain stable for logic.
mediapanel_youtube_state_label() {
    local key color

    case "$1" in
        missing)
            key=MP_YT_SETUP_STATE_MISSING
            color="${COLOR_RED}"
            ;;
        installed)
            key=MP_YT_SETUP_STATE_INSTALLED
            color="${COLOR_GREEN}"
            ;;
        valid)
            key=MP_YT_SETUP_STATE_VALID
            color="${COLOR_GREEN}"
            ;;
        invalid)
            key=MP_YT_SETUP_STATE_INVALID
            color="${COLOR_RED}"
            ;;
        present_unverified)
            key=MP_YT_SETUP_STATE_UNVERIFIED
            color="${COLOR_YELLOW}"
            ;;
        *)
            printf '%s\n' "$1"
            return 0
            ;;
    esac

    echo -e "${color}$(t "$key")${COLOR_RESET}"
}


mediapanel_youtube_api_status() {
    mediapanel_youtube_probe
    echo "$(t MP_YT_SETUP_HEADER)"
    echo "   $(t MP_YT_SETUP_DEPS "$(mediapanel_youtube_state_label "$YT_DEPS")")"
    echo "   $(t MP_YT_SETUP_CLIENT "$(mediapanel_youtube_state_label "$YT_CLIENT")")"
    echo "   $(t MP_YT_SETUP_TOKEN "$(mediapanel_youtube_state_label "$YT_TOKEN")")"
    echo "$(t MP_YT_SETUP_SETUP)"
}

mediapanel_youtube_next_step() {
    if [[ "$YT_DEPS" != installed ]]; then
        echo "$(t MP_YT_SETUP_NEXT_DEPS)"
    elif [[ "$YT_CLIENT" != valid ]]; then
        echo "$(t MP_YT_SETUP_NEXT_CLIENT)"
    elif [[ "$YT_TOKEN" != present_unverified ]]; then
        echo "$(t MP_YT_SETUP_NEXT_AUTH)"
    else
        echo "$(t MP_YT_SETUP_NEXT_TEST)"
    fi
}

mediapanel_youtube_instructions() {
    echo "===================================================="
    echo "$(t MP_YT_SETUP_INSTRUCTION_1)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_2)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_3)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_4)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_5)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_6)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_7)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_8)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_9)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_10)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_11)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_12)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_13)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_14)"
    echo
    echo "$(t MP_YT_SETUP_INSTRUCTION_15)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_16)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_17)"
    echo "$(t MP_YT_SETUP_INSTRUCTION_18)"
    echo "===================================================="
}

mediapanel_youtube_install_credentials() {
    local src cfg dst tmp confirm
    cfg="$(mediapanel_youtube_config_dir)"
    dst="$cfg/client_secrets.json"
    echo "$(t MP_YT_SETUP_PATH_PROMPT)"
    read -r -p "$(t MP_YT_SETUP_FILE_PROMPT)" src || return 0
    [[ -n "$src" && -f "$src" ]] || { echo "$(t MP_YT_SETUP_FILE_MISSING)"; return 1; }
    python3 - "$src" <<'PY' || { echo "$(t MP_YT_SETUP_INVALID_JSON)"; return 1; }
import json,sys
with open(sys.argv[1], encoding='utf-8') as f: d=json.load(f)
a=d.get('installed', {})
assert isinstance(a,dict) and all(a.get(k) for k in ('client_id','client_secret','auth_uri','token_uri'))
PY
    if [[ -e "$dst" ]]; then
        read -r -p "$(t MP_YT_SETUP_REPLACE_PROMPT)" confirm || return 0
        [[ "$confirm" =~ ^[YyДдИи]$ ]] || { echo "$(t MP_YT_SETUP_CANCELLED)"; return 0; }
    fi
    (umask 077; mkdir -p -- "$cfg") || return 1
    tmp="$(mktemp "$cfg/.client_secrets.XXXXXXXX")" || return 1
    if ! cat -- "$src" > "$tmp" || ! chmod 600 "$tmp" || ! mv -f -- "$tmp" "$dst"; then
        rm -f -- "$tmp"
        echo "$(t MP_YT_SETUP_INSTALL_FAILED)"
        return 1
    fi
    echo "$(t MP_YT_SETUP_INSTALLED)"
    if [[ -f "$cfg/token.json" ]]; then
        echo "$(t MP_YT_SETUP_TOKEN_KEPT)"
    fi
}

# Worker is loaded from package directory and runs under the user venv.
mediapanel_youtube_worker() {
    local py worker
    py="$(youtube_api_python)"
    worker="${REMEDIA_YOUTUBE_WORKER:-${REMEDIA_LIB:-/usr/lib/remedia}/modules/mediapanel/ui/youtube_oauth.py}"
    [[ -x "$py" ]] || { echo "$(t MP_YT_SETUP_INSTALL_FIRST)"; return 1; }
    [[ -f "$worker" ]] || { echo "$(t MP_YT_SETUP_WORKER_MISSING "$worker")"; return 1; }
    "$py" "$worker" "$1" "$(mediapanel_youtube_config_dir)"
}

mediapanel_youtube_setup_menu() {
    local choice
    while true; do
        mediapanel_youtube_probe
        echo
        clear
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "$(t MP_YT_SETUP_TITLE "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo "$(t MP_YT_SETUP_DEPS "$(mediapanel_youtube_state_label "$YT_DEPS")")"
        echo "$(t MP_YT_SETUP_CLIENT "$(mediapanel_youtube_state_label "$YT_CLIENT")")"
        echo "$(t MP_YT_SETUP_TOKEN "$(mediapanel_youtube_state_label "$YT_TOKEN")")"
        mediapanel_youtube_next_step
        echo
        echo "$(t MP_YT_SETUP_MENU_DEPS)"
        echo "$(t MP_YT_SETUP_MENU_CLIENT)"
        echo "$(t MP_YT_SETUP_MENU_AUTH)"
        echo "$(t MP_YT_SETUP_MENU_CHECK)"
        echo "$(t MP_YT_SETUP_MENU_TEST)"
        echo "$(t MP_YT_SETUP_MENU_INSTRUCTIONS)"
        echo
        echo -e "$(t MP_YT_SETUP_BACK "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo
        read -r -p "$(t MP_YT_SETUP_CHOICE)" choice || return 0
        case "$choice" in
            1) mediapanel_install_youtube_api || true ;;
            2) mediapanel_youtube_install_credentials || true ;;
            3) mediapanel_youtube_worker authorize || true ;;
            4) mediapanel_youtube_worker check || true ;;
            5) mediapanel_youtube_worker test || true ;;
            6) mediapanel_youtube_instructions ;;
            0) return 0 ;;
            *) echo "$(t MP_YT_SETUP_INVALID_OPTION)" ;;
        esac
        read -r -p "$(t MP_YT_SETUP_CONTINUE)" _ || return 0
    done
}
