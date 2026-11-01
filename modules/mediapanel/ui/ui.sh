#!/usr/bin/env bash
# modules/mediapanel/ui/ui.sh = interaction

run_ingest_ui() {

    local result ok fail skip total error

    result="$(ingest_from_phone_v3)"

    # ========= GUARD =========
    if [[ -z "$result" ]]; then
        echo "$(t MP_UI_ERROR_EMPTY_RESULT)"
        return 1
    fi

    ok=$(echo "$result" | awk -F'"ok":' '{print $2}' | awk -F',' '{print $1}')
    fail=$(echo "$result" | awk -F'"fail":' '{print $2}' | awk -F',' '{print $1}')
    skip=$(echo "$result" | awk -F'"skip":' '{print $2}' | awk -F',' '{print $1}')
    total=$(echo "$result" | awk -F'"total":' '{print $2}' | awk -F',' '{print $1}')
    error=$(echo "$result" | awk -F'"error":"' '{print $2}' | cut -d'"' -f1)

    echo "=========================="
    echo "$(t MP_UI_INGEST_COMPLETE)"
    echo "--------------------------"
    echo "$(t MP_UI_OK "$ok")"
    echo "$(t MP_UI_FAIL "$fail")"
    echo "$(t MP_UI_SKIP "$skip")"
    echo "$(t MP_UI_TOTAL "$total")"
    echo "$(t MP_UI_ERROR "${error:-$(t MP_UI_NONE)}")"
    read -rp "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
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
        echo "$(t MP_UI_WARN_NO_TERMINAL_FOUND_RUNNING_INLINE)"
        bash -c "$cmd"
    fi
}

ffmpeg_help() {
    open_terminal "ffmpeg -h"
}

pause() {
    log_info "$(t MP_UI_WAITING_CONFIRMATION)"
    read -rp "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
}

# =========================
#  GUIDE
# =========================
show_stabilization_guide() {
    clear || true

    t MP_UI_GUIDE_STABILIZATION

    echo
    read -r -p "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
}

# =========================
# SET FILTERS GUIDE
# =========================
show_set_filters_guide() {
    clear || true

    t MP_UI_GUIDE_FILTER_SETS

    echo
    read -r -p "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
}

main_menu() {
    while true; do
        active="$(get_active_project 2>/dev/null || true)"
        echo
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "$(t MP_UI_REMEDIA_MEDIAPANEL_UI "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        if [[ -n "$active" ]]; then
            echo -e "$(t MP_UI_ACTIVE_PROJECT "${COLOR_BOLD}" "${COLOR_GREEN}" "${active}" "${COLOR_RESET}")"
        else
            echo -e "$(t MP_UI_ACTIVE_PROJECT_NONE "${COLOR_BOLD}" "${COLOR_RED}" "${COLOR_RESET}")"
        fi

        echo
        echo "$(t MP_UI_1_SYSTEM_STATUS)"
        echo "$(t MP_UI_2_PROJECTS)"
        echo "$(t MP_UI_3_FOOTAGE_INGEST_FROM_PHONE)"
        echo "$(t MP_UI_4_PRODUCTION)"
        echo "$(t MP_UI_5_EXPORT)"
        echo "$(t MP_UI_6_TOOLS)"   # ← ДОБАВИЛИ
        echo
        echo -e "$(t MP_UI_0_EXIT "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo

        read -rp "$(t MP_UI_CHOICE_1)" choice || continue

        case "$choice" in
            1) system_status ;;
            2) projects_menu ;;
            3) run_ingest_ui ;;
            4) production_menu ;;
            5) export_menu ;;
            6) tools_menu ;;   # ← ВМЕСТО video_tools_menu
            0) exit 0 ;;
            *) echo "$(t MP_UI_INVALID_OPTION)" ;;
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
        echo -e "$(t MP_UI_PROJECTS "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
        if [[ -n "$active" ]]; then
            echo -e "$(t MP_UI_ACTIVE_PROJECT "${COLOR_BOLD}" "${COLOR_GREEN}" "${active}" "${COLOR_RESET}")"
        else
            echo -e "$(t MP_UI_ACTIVE_PROJECT_NONE "${COLOR_BOLD}" "${COLOR_RED}" "${COLOR_RESET}")"
        fi
        echo
        echo "$(t MP_UI_1_SELECT_PROJECT)"
        echo "$(t MP_UI_2_CREATE)"
        echo "$(t MP_UI_3_LIST)"
        echo "$(t MP_UI_4_DELETE)"
        echo "$(t MP_UI_5_RESTORE_PROJECT)"
        echo "$(t MP_UI_6_PURGE_TRASH)"
        echo
        echo -e "$(t MP_UI_0_BACK "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo
        read -rp "$(t MP_UI_CHOICE_1_2)" choice

        case "$choice" in
            1)
                echo "$(t MP_UI_SELECT_PROJECT)"
                mapfile -t projects < <(project_list_raw)

                if (( ${#projects[@]} == 0 )); then
                    echo "$(t MP_UI_INFO_NO_PROJECTS)"
                    continue
                fi

                for i in "${!projects[@]}"; do
                    printf "%2d) %s\n" "$((i+1))" "${projects[$i]}"
                done

                read -rp "$(t MP_UI_CHOICE)" idx
                if ! [[ "$idx" =~ ^[0-9]+$ ]]; then
                    echo "$(t MP_UI_ERROR_INVALID_NUMBER)"
                    continue
                fi

                (( idx-- ))

                if (( idx < 0 || idx >= ${#projects[@]} )); then
                    echo "$(t MP_UI_ERROR_OUT_OF_RANGE)"
                    continue
                fi

                activate_project_full "${projects[$idx]}"
                ;;
            2)
                read -rp "$(t MP_UI_PROJECT_NAME)" name
                CLI_NAME="$name"
                CLI_NO_UI=0
                project_create
                ;;
            3)
                echo
                project_list
                echo
                read -rp "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
                ;;
            4)
                echo
                echo "$(t MP_UI_AVAILABLE_PROJECTS)"
                project_list
                echo

                read -rp "$(t MP_UI_PROJECT_TO_DELETE)" name

                [[ -z "$name" ]] && {
                    echo "$(t MP_UI_INFO_CANCELLED)"
                    return
                }

                CLI_PROJECT="$name"
                CLI_YES=0
                delete_project
                ;;
             5)
                echo
                echo "$(t MP_UI_AVAILABLE_DELETED_PROJECTS)"
                mapfile -t trash < <(
                    find "$TRASH_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort
                )

                if (( ${#trash[@]} == 0 )); then
                    echo "$(t MP_UI_INFO_TRASH_EMPTY)"
                    read -rp "$(t MP_UI_PRESS_ENTER)"
                    continue
                fi

                i=1
                for t in "${trash[@]}"; do
                    echo "$i) $t"
                    ((i++))
                done
                echo
                read -rp "$(t MP_UI_CHOICE)" idx

                [[ ! "$idx" =~ ^[0-9]+$ ]] && {
                    echo "$(t MP_UI_ERROR_INVALID_NUMBER)"
                    read -rp "$(t MP_UI_PRESS_ENTER)"
                    continue
                }

                ((idx--))

                (( idx < 0 || idx >= ${#trash[@]} )) && {
                    echo "$(t MP_UI_ERROR_OUT_OF_RANGE)"
                    read -rp "$(t MP_UI_PRESS_ENTER)"
                    continue
                }

                project_restore "${trash[$idx]}"
                echo
                read -rp "$(t MP_UI_PRESS_ENTER)"
                ;;
            6) purge_trash ;;
            0) return ;;   # ← ВАЖНО
            *)
                echo "$(t MP_UI_INVALID_OPTION)"
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
        echo -e "$(t MP_UI_SMART_PRODUCTION "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        if [[ -n "$active" ]]; then
            echo -e "$(t MP_UI_PROJECT "${COLOR_BOLD}" "${COLOR_GREEN}" "${active}" "${COLOR_RESET}")"
        else
            echo -e "$(t MP_UI_PROJECT_NONE "${COLOR_BOLD}" "${COLOR_RED}" "${COLOR_RESET}")"
        fi
        echo
        pipeline_status "$active"
        echo "$(t MP_UI_1_GENERATE_PROXY)"
        echo "$(t MP_UI_2_AUDIO_CLEANUP)"
        echo "$(t MP_UI_3_AUTO_SYNC_AUDIO)"
        echo "$(t MP_UI_4_BATCH_SCENE_SPLIT)"
        echo "$(t MP_UI_5_CREATE_SHOTCUT_PROJECT_FILE_MLT)"
        echo "$(t MP_UI_6_FULL_PIPELINE)"
        echo "$(t MP_UI_7_RESUME_PIPELINE)"
        echo "$(t MP_UI_8_LAUNCH_SHOTCUT)"
        echo "$(t MP_UI_9_STABILIZATION)"
        echo "$(t MP_UI_10_SET_FILTERS)"
        echo "$(t MP_UI_11_GENERATE_SUBTITLES)"
        echo "$(t MP_UI_12_RENDER_EXPORT_GENERATE_VIDEOS)"
        echo
        echo -e "$(t MP_UI_0_BACK "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo

        read -rp "$(t MP_UI_CHOICE_1_2)" choice

        case "$choice" in
            1)
               ui_run_step "$active" proxy ;;
            2)
               ui_run_step "$active" audio ;;
            3)
               ui_run_step "$active" sync ;;
            4)
               ui_run_step "$active" split ;;
            5)
               ui_run_step "$active" mlt ;;
            6) full_pipeline || true ;;
            7)
               if ! resume_pipeline; then
                   echo "$(t MP_UI_ERROR_PIPELINE_RESUME_FAILED)"
               fi
               ;;
            8) launch_shotcut || true ;;
            9)
               show_stabilization_guide
               ;;

            10)
               show_set_filters_guide
               ;;

            11)
               generate_subtitles
               read -rp "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
               ;;
            12)
                export_render || log_error "$(t MP_UI_RENDER_FAILED)"
                pause
                ;;
            0) return ;;
            *) echo "$(t MP_UI_INVALID_OPTION)" ;;
        esac
    done
}

export_menu() {
    while true; do
        local active
        active="$(get_active_project 2>/dev/null || true)"
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "$(t MP_UI_EXPORT "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo
                if [[ -n "$active" ]]; then
            echo -e "$(t MP_UI_ACTIVE_PROJECT "${COLOR_BOLD}" "${COLOR_GREEN}" "${active}" "${COLOR_RESET}")"
        else
            echo -e "$(t MP_UI_ACTIVE_PROJECT_NONE "${COLOR_BOLD}" "${COLOR_RED}" "${COLOR_RESET}")"
        fi
        echo
        echo "$(t MP_UI_1_MANUAL_YOUTUBE_UPLOAD)"
        echo "$(t MP_UI_2_EXPORT_YOUTUBE)"
        echo "$(t MP_UI_3_PROCESS_YOUTUBE_QUEUE)"
        echo "$(t MP_UI_4_YOUTUBE_QUEUE_STATUS)"
        echo "$(t MP_UI_5_ARCHIVE_PROJECT)"
        echo "$(t MP_UI_6_ARCHIVE_YOUTUBE_QUEUE_JOBS)"
        echo
        echo -e "$(t MP_UI_0_BACK "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo

        read -rp "$(t MP_UI_CHOICE_1_2)" choice

        case "$choice" in

            1)
                manual_youtube_upload ||
                    log_error "$(t MP_UI_YOUTUBE_UPLOAD_FAILED)"
                ;;

            2)
                export_youtube_queue ||
                    log_error "$(t MP_UI_YOUTUBE_EXPORT_FAILED)"
                ;;

            3)
                process_youtube_queue ||
                    log_error "$(t MP_UI_YOUTUBE_QUEUE_FAILED)"
                pause
                ;;

            4)
                youtube_queue_status ||
                    log_error "$(t MP_UI_YOUTUBE_STATUS_FAILED)"
                pause
                ;;

            5)
                archive_project ||
                    log_error "$(t MP_UI_ARCHIVE_FAILED)"
                pause
                ;;

            6)  archive_youtube_queue_job ||
                    log_error "$(t MP_UI_YOUTUBE_ARCHIVE_FAILED)"
                pause
                ;;

            0)
                return
                ;;

            *)
                echo "$(t MP_UI_INVALID_OPTION)"
                pause
                ;;
        esac
    done
}

purge_trash() {

    echo
    echo -e "$(t MP_UI_WARNING_THIS_WILL_PERMANENTLY_DELETE_ALL_TRASH_PROJECTS "${COLOR_RED}" "${COLOR_RESET}")"
    echo

    read -rp "$(t MP_UI_TYPE_PURGE_TO_CONFIRM)" confirm
    confirm=${confirm^^}

    [[ "$confirm" != "PURGE" ]] && {
        echo "$(t MP_UI_CANCELLED)"
        pause
        return
    }

    echo
    echo "$(t MP_UI_CLEANING_TRASH)"

    purge_trash_core   # ← ВАЖНО

    echo
    echo -e "$(t MP_UI_TRASH_CLEANED "${COLOR_GREEN}" "${COLOR_RESET}")"

    pause
}


tools_menu() {
    while true; do
        clear || true

        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo -e "$(t MP_UI_TOOLS "${COLOR_BOLD}" "${COLOR_CYAN}" "${COLOR_RESET}")"
        echo -e "${COLOR_BOLD}${COLOR_CYAN}====================================================${COLOR_RESET}"
        echo

        echo "$(t MP_UI_1_VIDEO_TOOLS)"
        echo "$(t MP_UI_2_GRAPHICS_TOOLS)"
        echo "$(t MP_UI_3_AUDIO_TOOLS)"
        echo
        echo -e "$(t MP_UI_0_BACK "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo

        read -rp "$(t MP_UI_CHOICE_1_2)" choice

        case "$choice" in
            1) video_tools_menu ;;
            2) graphics_tools_menu ;;
            3) audio_tools_menu;;
            0) return ;;
            *) echo "$(t MP_UI_INVALID_OPTION)" ;;
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
        echo -e "$(t MP_UI_0_BACK_2 "${COLOR_YELLOW}" "${COLOR_RESET}")"
        echo
        appmap[0]="back"

        read -rp "$(t MP_UI_CHOICE_1_2)" choice

        # защита от мусора
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo "$(t MP_UI_INVALID_OPTION)"
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
                read -rp "$(t MP_UI_PRESS_ENTER_TO_CONTINUE)"
                ;;
            "")
                echo "$(t MP_UI_INVALID_OPTION)"
                sleep 1
                ;;
        esac
    done
}

video_tools_menu() {
    build_menu "$(t MP_UI_VIDEO_TOOLS)" \
        "Shotcut||flatpak:org.shotcut.Shotcut" \
        "OBS Studio|cmd:obs|flatpak:com.obsproject.Studio" \
        "VLC Media Player|cmd:vlc|flatpak:org.videolan.VLC" \
        "$(t MP_UI_OPEN_VIDEO)|func:open_video_dialog|" \
        "$(t MP_UI_FFMPEG_HELP)|func:ffmpeg_help|"
}

graphics_tools_menu() {
    build_menu "$(t MP_UI_GRAPHICS_TOOLS)" \
        "GIMP|cmd:gimp|flatpak:org.gimp.GIMP" \
        "Inkscape|cmd:inkscape|flatpak:org.inkscape.Inkscape" \
        "Krita|cmd:krita|flatpak:org.kde.krita"
}

audio_tools_menu() {
    build_menu "$(t MP_UI_AUDIO_TOOLS)" \
        "Audacity|cmd:audacity|flatpak:org.audacityteam.Audacity" \
        "Ardour|cmd:ardour|flatpak:org.ardour.Ardour" \
        "LMMS|cmd:lmms|flatpak:io.lmms.LMMS"
}


