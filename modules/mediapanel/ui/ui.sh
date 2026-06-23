#!/usr/bin/env bash
# modules/mediapanel/ui/ui.sh = interaction

run_ingest_ui() {

    local result ok fail skip total error

    result="$(ingest_from_phone_v3)"

    # ========= GUARD =========
    if [[ -z "$result" ]]; then
        echo "ERROR: empty result"
        return 1
    fi

    ok=$(echo "$result" | awk -F'"ok":' '{print $2}' | awk -F',' '{print $1}')
    fail=$(echo "$result" | awk -F'"fail":' '{print $2}' | awk -F',' '{print $1}')
    skip=$(echo "$result" | awk -F'"skip":' '{print $2}' | awk -F',' '{print $1}')
    total=$(echo "$result" | awk -F'"total":' '{print $2}' | awk -F',' '{print $1}')
    error=$(echo "$result" | awk -F'"error":"' '{print $2}' | cut -d'"' -f1)

    echo "=========================="
    echo "INGEST COMPLETE"
    echo "--------------------------"
    echo "OK:     $ok"
    echo "FAIL:   $fail"
    echo "SKIP:   $skip"
    echo "TOTAL:  $total"
    echo "ERROR:  ${error:-none}"
    read -rp "Press Enter to continue..."
}

get_step_status() {
    local project="$1"
    local key="$2"

    local val
    val="$(pipeline_get "$project" "$key" || echo "pending")"

    echo "$val"
}

is_step_enabled() {
    local project="$1"
    local step="$2"

    # UI-only validation (no business gating)

    local state
    state="$(pipeline_get "$project" "$step" || echo "pending")"

    # optional: можно улучшить визуал
    [[ "$state" != "disabled" ]]
}

render_step() {
    local label="$1"
    local status="$2"
    local enabled="$3"

    local icon color

    if [[ "$enabled" != "true" ]]; then
        icon="✖"
        color="$RED"
    else
        case "$status" in
            done)    icon="✔"; color="$COLOR_GREEN" ;;
            pending) icon="⟳"; color="$COLOR_YELLOW" ;;
            *)       icon="?"; color="$COLOR_MAGENTA" ;;
        esac
    fi

    echo -e "${color}${icon} ${label}${COLOR_RESET}"
}

ui_run_step() {
    local project="$1"
    local step="$2"

    [[ -z "$project" || -z "$step" ]] && return 1

    run_step "$project" "$step"
}

open_terminal() {
    local cmd="$1"

    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal -- bash -c "$cmd; exec bash"
    elif command -v konsole >/dev/null 2>&1; then
        konsole -e bash -c "$cmd; exec bash"
    elif command -v xterm >/dev/null 2>&1; then
        xterm -e "$cmd"
    else
        echo "[WARN] No terminal found, running inline"
        bash -c "$cmd"
    fi
}

ffmpeg_help() {
    open_terminal "ffmpeg -h"
}

pause() {
    log_info "Waiting user confirmation..."
    read -rp "Press Enter to continue..."
}

main_menu() {
    while true; do
        active="$(get_active_project 2>/dev/null || true)"
        echo
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "              ${COLOR_BOLD}${COLOR_CYAN}REMEDIA MEDIAPANEL UI${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        if [[ -n "$active" ]]; then
            echo -e "${COLOR_BOLD}Active project: ${COLOR_GREEN}${active}${COLOR_RESET}"
        else
            echo -e "${COLOR_BOLD}Active project: ${COLOR_RED}none${COLOR_RESET}"
        fi

        echo
        echo "1) System status"
        echo "2) Projects"
        echo "3) Footage ingest from phone"
        echo "4) Production"
        echo "5) Export"
        echo "6) Tools"   # ← ДОБАВИЛИ
        echo
        echo -e "${COLOR_YELLOW}0) Exit${COLOR_RESET}"
        echo

        read -rp "Choice [1-#]: " choice || continue

        case "$choice" in
            1) system_status ;;
            2) projects_menu ;;
            3) run_ingest_ui ;;
            4) production_menu ;;
            5) export_menu ;;
            6) tools_menu ;;   # ← ВМЕСТО video_tools_menu
            0) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

projects_menu() {
    set +e
    while true; do
        active="$(get_active_project 2>/dev/null || true)"
        echo
        clear || true
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                   ${COLOR_BOLD}${COLOR_CYAN}Projects${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
        if [[ -n "$active" ]]; then
            echo -e "${COLOR_BOLD}Active project: ${COLOR_GREEN}${active}${COLOR_RESET}"
        else
            echo -e "${COLOR_BOLD}Active project: ${COLOR_RED}none${COLOR_RESET}"
        fi
        echo
        echo "1) Select project"
        echo "2) Create"
        echo "3) List"
        echo "4) Delete"
        echo "5) Restore project"
        echo "6) Purge trash"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo
        read -rp "Choice [1-#]> " choice

        case "$choice" in
            1)
                echo "Select project:"
                mapfile -t projects < <(project_list_raw)

                if (( ${#projects[@]} == 0 )); then
                    echo "[INFO] no projects"
                    continue
                fi
                
                for i in "${!projects[@]}"; do
                    printf "%2d) %s\n" "$((i+1))" "${projects[$i]}"
                done
                
                read -rp "choice #)> " idx
                if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
                    echo "[ERROR] invalid number"
                    continue
                fi

                (( idx-- ))

                if (( idx < 0 || idx >= ${#projects[@]} )); then
                    echo "[ERROR] out of range"
                    continue
                fi  
                
                activate_project_full "${projects[$idx]}"
                ;;
            2)
                read -rp "Project name: " name
                CLI_NAME="$name"
                CLI_NO_UI=0
                project_create
                ;;
            3)
                echo
                project_list
                echo
                read -rp "Press Enter to continue..."
                ;;
            4)
                echo
                echo "Available projects:"
                project_list
                echo

                read -rp "Project to delete: " name

                [[ -z "$name" ]] && {
                    echo "[INFO] cancelled"
                    return
                }

                CLI_PROJECT="$name"
                CLI_YES=0
                delete_project
                ;;
             5)
                echo
                echo "Available deleted projects:"
                mapfile -t trash < <(
                    find "$TRASH_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort
                )

                if (( ${#trash[@]} == 0 )); then
                    echo "[INFO] trash empty"
                    read -rp "Press Enter..." 
                    continue
                fi

                i=1
                for t in "${trash[@]}"; do
                    echo "$i) $t"
                    ((i++))
                done
                echo
                read -rp "choice #)> " idx

                [[ ! "$idx" =~ ^[0-9]+$ ]] && {
                    echo "[ERROR] invalid number"
                    read -rp "Press Enter..."
                    continue
                }

                ((idx--))

                (( idx < 0 || idx >= ${#trash[@]} )) && {
                    echo "[ERROR] out of range"
                    read -rp "Press Enter..."
                    continue
                }

                project_restore "${trash[$idx]}"
                echo
                read -rp "Press Enter..."
                ;;
            6) purge_trash ;;
            0) return ;;   # ← ВАЖНО
            *)
                echo "Invalid option"
                ;;
        esac
    done
    set -e
}

production_menu() {
    while true; do
        local active
        active="$(get_active_project 2>/dev/null || true)"
        pipeline_load "$active"

        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "               ${COLOR_BOLD}${COLOR_CYAN}Smart Production${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        if [[ -n "$active" ]]; then
            echo -e ${COLOR_BOLD}"Project: ${COLOR_GREEN}${active}${COLOR_RESET}"
        else
            echo -e "${COLOR_BOLD}Project: ${COLOR_RED}none${COLOR_RESET}"
        fi
        echo       
        pipeline_status "$active"      
        echo "1) Generate proxy"
        echo "2) Audio cleanup"
        echo "3) Auto sync audio"
        echo "4) Batch scene split"
        echo "5) Full pipeline"
        echo "6) Resume pipeline"
        echo "7) Launch Shotcut"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo

        read -rp "Choice [1-#]> " choice

        case "$choice" in
            1)
               ui_run_step "$active" proxy ;;
            2)
               ui_run_step "$active" audio ;;
            3)
               ui_run_step "$active" sync ;;
            4)
               ui_run_step "$active" split ;;
            5) full_pipeline || true ;;
            6) resume_pipeline || true ;;
            7) launch_shotcut || true ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
    done
}

export_menu() {
    while true; do
        local active
        active="$(get_active_project 2>/dev/null || true)"
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                 ${COLOR_BOLD}${COLOR_CYAN}Export${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
                if [[ -n "$active" ]]; then
            echo -e "${COLOR_BOLD}Active project: ${COLOR_GREEN}${active}${COLOR_RESET}"
        else
            echo -e "${COLOR_BOLD}Active project: ${COLOR_RED}none${COLOR_RESET}"
        fi
        echo
        echo "1) Render Export (generate videos)"
        echo "2) Export → YouTube (upload/select)"
        echo "3) Archive project"
        echo
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo

        read -rp "Choice [1-#]> " choice

        case "$choice" in
            1) 
                export_render || log_error "Render export failed"
                pause
                ;;           
            2)
                export_youtube || log_error "Export failed"
                pause
                ;;
            3)
                archive_project || log_error "Archive failed"
                pause
                ;;
            0)
                return
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

purge_trash() {

    echo
    echo -e "${COLOR_RED}WARNING:${COLOR_RESET} This will permanently delete ALL trash projects."
    echo

    read -rp " Type PURGE to confirm: " confirm
    confirm=${confirm^^}

    [[ "$confirm" != "PURGE" ]] && {
        echo " Cancelled."
        pause
        return
    }

    echo
    echo "  Cleaning trash..."

    purge_trash_core   # ← ВАЖНО

    echo
    echo -e " ${COLOR_GREEN}✓${COLOR_RESET} Trash cleaned."

    pause
}


tools_menu() {
    while true; do
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                  ${COLOR_BOLD}${COLOR_CYAN}Tools${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        echo "1) Video tools"
        echo "2) Graphics tools"
        echo "3) Audio tools"
        echo 
        echo -e "${COLOR_YELLOW}0) Back${COLOR_RESET}"
        echo

        read -rp "Choice [1-#]> " choice

        case "$choice" in
            1) video_tools_menu ;;
            2) graphics_tools_menu ;;
            3) audio_tools_menu;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
    done
}

build_menu() {
    local title="$1"
    shift

    local -a items=("$@")
    local -A appmap

    while true; do
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "                ${COLOR_BOLD}${COLOR_CYAN}${title}${COLOR_RESET}"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        local i=1
        appmap=()   # ← важно очищать

        for item in "${items[@]}"; do
            IFS="|" read -r label cmd flatpak <<< "$item"

            # cmd:...
            if [[ "$cmd" == cmd:* ]]; then
                local bin="${cmd#cmd:}"

                if command -v "$bin" &>/dev/null; then
                    echo " $i) $label"
                    appmap[$i]="$cmd"
                    ((i++))
                    continue
                fi
            fi
            
            if [[ "$cmd" == func:* ]]; then
                local fn="${cmd#func:}"

                # проверка что функция существует
                if declare -F "$fn" >/dev/null; then
                    echo " $i) $label"
                    appmap[$i]="$cmd"
                    ((i++))
                   continue
                else
                    # можно лог для отладки
                    # echo "[DEBUG] function not found: $fn"
                    :
                fi
            fi

            # flatpak:...
            if [[ "$flatpak" == flatpak:* ]]; then
                local pkg="${flatpak#flatpak:}"

                if has_flatpak "$pkg"; then
                    echo " $i) $label"
                    appmap[$i]="$flatpak"
                    ((i++))
                    continue
                fi
            fi
        done

        echo
        echo -e "${COLOR_YELLOW} 0) Back${COLOR_RESET}"
        echo
        appmap[0]="back"

        read -rp "Choice [1-#]> " choice

        # защита от мусора
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo "Invalid option"
            sleep 1
            continue
        fi

        local action="${appmap[$choice]:-}"
        case "$action" in
            back)
                return
                ;;

            cmd:*)
                local bin="${appmap[$choice]#cmd:}"
                "$bin"
                ;;

            flatpak:*)
                local pkg="${appmap[$choice]#flatpak:}"
                flatpak run "$pkg"
                ;;
            func:*)
                local fn="${appmap[$choice]#func:}"
                "$fn"
                read -rp "Press Enter to continue..."
                ;;
            "")
                echo "Invalid option"
                sleep 1
                ;;
        esac
    done
}

video_tools_menu() {
    build_menu "VIDEO TOOLS" \
        "Shotcut||flatpak:org.shotcut.Shotcut" \
        "OBS Studio|cmd:obs|flatpak:com.obsproject.Studio" \
        "VLC Media Player|cmd:vlc|flatpak:org.videolan.VLC" \
        "Open video…|func:open_video_dialog|" \
        "ffmpeg help|func:ffmpeg_help|"
}

graphics_tools_menu() {
    build_menu "GRAPHICS TOOLS" \
        "GIMP|cmd:gimp|flatpak:org.gimp.GIMP" \
        "Inkscape|cmd:inkscape|flatpak:org.inkscape.Inkscape" \
        "Krita|cmd:krita|flatpak:org.kde.krita"
}

audio_tools_menu() {
    build_menu "AUDIO TOOLS" \
        "Audacity|cmd:audacity|flatpak:org.audacityteam.Audacity" \
        "Ardour|cmd:ardour|flatpak:org.ardour.Ardour" \
        "LMMS|cmd:lmms|flatpak:io.lmms.LMMS"
}


