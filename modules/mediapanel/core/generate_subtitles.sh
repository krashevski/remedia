#!/usr/bin/env bash
# modules/mediapanel/core/generate_subtitles.sh
#
# ============================================================
# GENERATE SUBTITLES
#
# Workflow:
#
#   <project>/<project>.mlt
#              |
#              v
#   subtitles/<project>_subtitles.wav
#              |
#              v
#   Whisper large-v3
#              |
#              v
#   subtitles_new.srt
#              |
#              v
#   subtitles_new.srt.bak
#              |
#              v
#   remove ONLY 100% identical adjacent subtitles
#              |
#              v
#   subtitles_final.srt
#
# Shotcut:
#   org.shotcut.Shotcut Flatpak
#
# Whisper model:
#
#   ~/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/
#       extensions/whispermodel/ggml-large-v3-q5_0.bin
#
# ============================================================

# Shared preferences are also available when generation is called outside the UI.
if ! declare -F mediapanel_subtitle_languages_load >/dev/null; then
    # shellcheck source=modules/mediapanel/core/subtitle_languages.sh
    source "$(dirname -- "${BASH_SOURCE[0]}")/subtitle_languages.sh" || return 1
fi

generate_subtitles() {

    local project
    project="$(require_active_project)" || return 1

    local project_path="$PROJECT_DIR/$project"
    local video_dir="$project_path/video"
    local short_dir="$project_path/short"

    # --------------------------------------------------------
    # FIND AVAILABLE MLT PROJECTS
    # --------------------------------------------------------

    local -a mlt_files=()
    local mlt=""

    mapfile -d '' -t mlt_files < <(
        {
            if [[ -d "$video_dir" ]]; then
                find "$video_dir" \
                    -maxdepth 1 \
                    -type f \
                    -iname "*.mlt" \
                    -print0
            fi

            if [[ -d "$short_dir" ]]; then
                find "$short_dir" \
                    -maxdepth 1 \
                    -type f \
                    -iname "*.mlt" \
                    -print0
            fi
        } | sort -z
    )

    if (( ${#mlt_files[@]} == 0 )); then
        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_NO_SHOTCUT_MLT_PROJECTS_FOUND)"
        echo
        echo "$(t MP_GENERATE_SUBTITLES_SEARCHED)"
        echo "  $video_dir"
        echo "  $short_dir"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_NO_SHOTCUT_MLT_PROJECTS_FOUND_FOR_SUBTITLE_GENERATION)"

        return 1
    fi

    echo
    echo "$(t MP_EXPORT_RENDER_AVAILABLE_SHOTCUT_PROJECTS)"
    echo "------------------------------------------------"

    local i=1
    local file
    local label

    for file in "${mlt_files[@]}"; do
        case "$file" in
            "$video_dir"/*)
                label="$(t MP_KIND_VIDEO)"
                ;;
            "$short_dir"/*)
                label="$(t MP_KIND_SHORT)"
                ;;
            *)
                label="$(t MP_KIND_MLT)"
                ;;
         esac

         printf '%2d) [%-5s] %s\n' \
             "$i" \
             "$label" \
             "$(basename "$file")"

         ((i++))
     done

     echo "------------------------------------------------"
     echo "$(t MP_GENERATE_SUBTITLES_SELECT_ONE_PROJECT_FOR_SUBTITLE_GENERATION)"
     echo
     echo -e "$(t MP_EXPORT_RENDER_ENTER_0_TO_RETURN "${COLOR_YELLOW}" "${COLOR_RESET}")"
     echo

     local choice=""
     read -rp "$(t MP_EXPORT_SELECTION)" choice

    if [[ "$choice" == "0" ]]; then
        return 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
        (( choice < 1 || choice > ${#mlt_files[@]} )); then

        echo "$(t MP_EXPORT_RENDER_ERROR_INVALID_SELECTION "$choice")"

        mediapanel_log_error "$project" \
             "$(t MP_GENERATE_SUBTITLES_INVALID_SUBTITLE_MLT_SELECTION "$choice")"

        return 1
    fi

    mlt="${mlt_files[$((choice - 1))]}"

    echo
    echo "$(t MP_GENERATE_SUBTITLES_SELECTED)"
    echo "  $(basename "$mlt")"
    echo

    local mlt_name
    mlt_name="$(basename "$mlt" .mlt)"

    local subtitles_dir="$project_path/subtitles/$mlt_name"

    local wav="$subtitles_dir/${mlt_name}_subtitles.wav"

    local srt_new="$subtitles_dir/subtitles_new.srt"
    local srt_bak="$subtitles_dir/subtitles_new.srt.bak"
    local srt_final="$subtitles_dir/subtitles_final.srt"

    local model="$HOME/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/extensions/whispermodel/ggml-large-v3-q5_0.bin"

    # CLI_LANGUAGE > SUBTITLE_LANGUAGE > saved language menu.
    # In no-UI mode, use the first saved language if no explicit default exists.
    local language language_name language_rc
    if mediapanel_subtitle_language_select; then
        language="$MEDIAPANEL_SUBTITLE_LANGUAGE"
    else
        language_rc=$?
        # Cancellation is a successful return to the caller's menu.
        (( language_rc == 2 )) && return 0
        return "$language_rc"
    fi
    language_name="$(mediapanel_subtitle_language_name "$language")" || return 1

    mkdir -p "$subtitles_dir" || {
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_CANNOT_CREATE_SUBTITLES_DIRECTORY)"
        echo "        $subtitles_dir"
        return 1
    }


    # ========================================================
    # HEADER
    # ========================================================

    echo
    echo "=================================================="
    echo "$(t MP_GENERATE_SUBTITLES_MEDIAPANEL_GENERATE_SUBTITLES)"
    echo "=================================================="
    echo "$(t MP_EXPORT_RENDER_PROJECT "$project")"
    echo "$(t MP_EXPORT_RENDER_MLT_2 "$mlt")"
    echo "$(t MP_GENERATE_SUBTITLES_WAV "$wav")"
    echo "$(t MP_GENERATE_SUBTITLES_MODEL "$model")"
    echo "$(t MP_GENERATE_SUBTITLES_LANGUAGE "$language_name" "$language")"
    echo "$(t MP_EXPORT_RENDER_OUTPUT "$srt_final")"
    echo "=================================================="
    echo

    log_info "$(t MP_GENERATE_SUBTITLES_GENERATE_SUBTITLES_STARTED)"
    log_project "$project" "Subtitle generation started"


    # ========================================================
    # CHECK PROJECT
    # ========================================================

    if [[ ! -d "$project_path" ]]; then

        echo "$(t MP_EXPORT_RENDER_ERROR_PROJECT_DIRECTORY_NOT_FOUND)"
        echo "        $project_path"

        mediapanel_log_error "$project" \
            "$(t MP_EXPORT_PROJECT_DIRECTORY_NOT_FOUND "$project_path")"

        return 1
    fi


    # ========================================================
    # CHECK MAIN MLT
    #
    # ONLY:
    #
    #   $project/$project.mlt
    #
    # is used.
    #
    # Other MLT files are deliberately ignored.
    # ========================================================

    if [[ ! -f "$mlt" ]]; then

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_MAIN_MLT_PROJECT_NOT_FOUND)"
        echo "        $mlt"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_MAIN_MLT_PROJECT_NOT_FOUND "$mlt")"

        return 1
    fi

    if [[ ! -r "$mlt" ]]; then

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_MAIN_MLT_PROJECT_IS_NOT_READABLE)"
        echo "        $mlt"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_MAIN_MLT_PROJECT_IS_NOT_READABLE "$mlt")"

        return 1
    fi


    # ========================================================
    # CHECK WHISPER MODEL
    # ========================================================

    if [[ ! -f "$model" ]]; then

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WHISPER_MODEL_NOT_FOUND)"
        echo "        $model"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_WHISPER_MODEL_NOT_FOUND "$model")"

        return 1
    fi

    if [[ ! -r "$model" ]]; then

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WHISPER_MODEL_IS_NOT_READABLE)"
        echo "        $model"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_WHISPER_MODEL_IS_NOT_READABLE "$model")"

        return 1
    fi


    # ========================================================
    # FIND MELT
    # ========================================================

    local MELT_CMD=()
    local USE_FLATPAK_MELT=0

    if command -v melt >/dev/null 2>&1; then

        MELT_CMD=(melt)

        log_info "$(t MP_EXPORT_RENDER_MLT_ENGINE_SYSTEM_MELT)"

    elif command -v flatpak >/dev/null 2>&1 \
        && flatpak info org.shotcut.Shotcut >/dev/null 2>&1; then

        USE_FLATPAK_MELT=1

        MELT_CMD=(
            flatpak
            run
            --filesystem="$project_path:rw"
            --filesystem="$HOME/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/extensions/whispermodel:ro"
            --command=melt
            org.shotcut.Shotcut
        )

        log_info "$(t MP_EXPORT_RENDER_MLT_ENGINE_SHOTCUT_FLATPAK_MELT)"
        log_info "$(t MP_GENERATE_SUBTITLES_FLATPAK_FILESYSTEM_RW "$project_path")"

    else

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_MELT_NOT_FOUND)"
        echo
        echo "$(t MP_GENERATE_SUBTITLES_INSTALL_MLT_OR_SHOTCUT_FLATPAK)"
        echo

        mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_MELT_NOT_FOUND)"

        return 1
    fi


    # ========================================================
    # CHECK MELT
    # ========================================================

    if ! "${MELT_CMD[@]}" -version >/dev/null 2>&1; then

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_MELT_IS_NOT_EXECUTABLE)"

        mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_MELT_IS_NOT_EXECUTABLE)"

        return 1
    fi

    local melt_version

    melt_version="$(
        "${MELT_CMD[@]}" -version 2>&1 |
            head -n 1
    )"

    log_info "$(t MP_EXPORT_RENDER_MLT "$melt_version")"


    # ========================================================
    # FIND WHISPER CLI
    # ========================================================

    local WHISPER_CMD=()
    local USE_FLATPAK_WHISPER=0

    if command -v whisper-cli >/dev/null 2>&1; then

        WHISPER_CMD=(whisper-cli)

        log_info "$(t MP_GENERATE_SUBTITLES_WHISPER_SYSTEM_WHISPER_CLI)"

    elif command -v flatpak >/dev/null 2>&1 \
        && flatpak info org.shotcut.Shotcut >/dev/null 2>&1; then

        USE_FLATPAK_WHISPER=1

        WHISPER_CMD=(
            flatpak
            run
            --filesystem="$project_path:rw"
            --filesystem="$HOME/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/extensions/whispermodel:ro"
            --command=whisper-cli
            org.shotcut.Shotcut
        )

        log_info "$(t MP_GENERATE_SUBTITLES_WHISPER_SHOTCUT_FLATPAK_WHISPER_CLI)"
        log_info "$(t MP_GENERATE_SUBTITLES_FLATPAK_FILESYSTEM_RW "$project_path")"

    else

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WHISPER_CLI_NOT_FOUND)"
        echo
        echo "$(t MP_GENERATE_SUBTITLES_EXPECTED_SHOTCUT_FLATPAK_WHISPER_CLI)"
        echo

        mediapanel_log_error "$project" "$(t MP_GENERATE_SUBTITLES_WHISPER_CLI_NOT_FOUND)"

        return 1
    fi


    # ========================================================
    # CHECK WHISPER
    # ========================================================

    if ! "${WHISPER_CMD[@]}" --help >/dev/null 2>&1; then

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WHISPER_CLI_IS_NOT_EXECUTABLE)"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_WHISPER_CLI_IS_NOT_EXECUTABLE)"

        return 1
    fi


    # ========================================================
    # STEP 1
    # RENDER WAV FROM MAIN MLT
    # ========================================================

    echo
    echo "$(t MP_GENERATE_SUBTITLES_1_4_RENDERING_AUDIO_FROM_MLT)"
    echo

    log_info "$(t MP_GENERATE_SUBTITLES_RENDERING_SUBTITLE_WAV_FROM "$mlt")"

    if [[ -f "$wav" ]]; then

        echo "$(t MP_GENERATE_SUBTITLES_WARN_EXISTING_WAV_WILL_BE_REPLACED)"
        echo "       $wav"

        log_info "$(t MP_GENERATE_SUBTITLES_REMOVING_EXISTING_SUBTITLE_WAV)"

        rm -f "$wav" || {

            echo "$(t MP_GENERATE_SUBTITLES_ERROR_CANNOT_REMOVE_EXISTING_WAV)"

            mediapanel_log_error "$project" \
                "$(t MP_GENERATE_SUBTITLES_CANNOT_REMOVE_EXISTING_SUBTITLE_WAV)"

            return 1
        }
    fi


    # --------------------------------------------------------
    # IMPORTANT:
    #
    # When using Flatpak melt, the project directory is exposed
    # inside the sandbox with the SAME absolute path.
    #
    # Therefore:
    #
    #   /mnt/storage/Videos/projects/012_Учебное/...
    #
    # remains the same path inside melt.
    #
    # --------------------------------------------------------

    LC_ALL=C.UTF-8 \
    "${MELT_CMD[@]}" \
        "$mlt" \
        -consumer "avformat:$wav" \
        acodec=pcm_s16le \
        ar=16000 \
        ac=1

    local rc=$?

    if (( rc != 0 )); then

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_AUDIO_RENDERING_FAILED)"
        echo "$(t MP_GENERATE_SUBTITLES_EXIT_CODE "$rc")"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_SUBTITLE_WAV_RENDERING_FAILED_EXIT_CODE "$rc")"

        rm -f "$wav"

        return "$rc"
    fi


    # ========================================================
    # CHECK WAV
    # ========================================================

    if [[ ! -s "$wav" ]]; then

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WAV_WAS_NOT_CREATED_OR_IS_EMPTY)"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_SUBTITLE_WAV_MISSING_OR_EMPTY)"

        rm -f "$wav"

        return 1
    fi


    log_project "$project" \
        "Subtitle WAV created: $(basename "$wav")"

    echo
    echo "$(t MP_GENERATE_SUBTITLES_OK_WAV_CREATED)"
    echo "     $wav"
    echo


    # ========================================================
    # STEP 2
    # WHISPER
    # ========================================================

    echo
    echo "$(t MP_GENERATE_SUBTITLES_2_4_RUNNING_WHISPER_LARGE_V3)"
    echo

    log_info "$(t MP_GENERATE_SUBTITLES_WHISPER_MODEL "$model")"
    log_info "$(t MP_GENERATE_SUBTITLES_WHISPER_LANGUAGE "$language_name" "$language")"

    # Always create a fresh SRT.
    rm -f "$srt_new"

    "${WHISPER_CMD[@]}" \
        -m "$model" \
        -f "$wav" \
        -osrt \
        -of "${srt_new%.srt}" \
        -l "$language" \
        -pp

    rc=$?


    if (( rc != 0 )); then

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WHISPER_TRANSCRIPTION_FAILED)"
        echo "$(t MP_GENERATE_SUBTITLES_EXIT_CODE "$rc")"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_WHISPER_TRANSCRIPTION_FAILED_EXIT_CODE "$rc")"

        rm -f "$srt_new"

        return "$rc"
    fi


    # ========================================================
    # CHECK SRT
    # ========================================================

    if [[ ! -s "$srt_new" ]]; then

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_WHISPER_DID_NOT_CREATE_SUBTITLES_NEW_SRT)"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_WHISPER_PRODUCED_NO_SRT)"

        return 1
    fi


    log_project "$project" \
        "Whisper transcription completed: subtitles_new.srt"

    echo
    echo "$(t MP_GENERATE_SUBTITLES_OK_WHISPER_TRANSCRIPTION_COMPLETED)"
    echo "     $srt_new"
    echo


    # ========================================================
    # STEP 3
    # BACKUP
    # ========================================================

    echo
    echo "$(t MP_GENERATE_SUBTITLES_3_4_CREATING_SRT_BACKUP)"
    echo


    cp -f "$srt_new" "$srt_bak" || {

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_FAILED_TO_CREATE_BACKUP)"
        echo "        $srt_bak"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_FAILED_TO_CREATE_SUBTITLES_NEW_SRT_BAK)"

        return 1
    }


    echo "$(t MP_GENERATE_SUBTITLES_OK_BACKUP_CREATED)"
    echo "     $srt_bak"

    log_project "$project" \
        "SRT backup created: subtitles_new.srt.bak"


    # ========================================================
    # STEP 4
    # REMOVE ONLY 100% IDENTICAL ADJACENT SUBTITLES
    #
    # IMPORTANT:
    #
    # A subtitle is removed ONLY if:
    #
    #   previous subtitle text == current subtitle text
    #
    # and they are adjacent.
    #
    # Timestamps are NOT compared.
    #
    # All other subtitles remain unchanged.
    #
    # Resulting blocks are renumbered.
    # ========================================================

    echo
    echo "$(t MP_GENERATE_SUBTITLES_4_4_REMOVING_EXACT_ADJACENT_DUPLICATE_SUBTITLES)"
    echo


    local tmp_srt

    tmp_srt="$(
        mktemp "${subtitles_dir}/.subtitles_final.XXXXXX"
    )" || {

        echo "$(t MP_GENERATE_SUBTITLES_ERROR_CANNOT_CREATE_TEMPORARY_SRT)"

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_CANNOT_CREATE_TEMPORARY_SRT_FILE)"

        return 1
    }


    awk '
    BEGIN {
        RS = ""
        ORS = "\n\n"

        count = 0
        previous_text = ""
        have_previous = 0
    }

    {
        n = split($0, lines, "\n")

        # ----------------------------------------------------
        # Valid subtitle must contain:
        #
        # 1. sequence
        # 2. timestamp
        # 3. text
        # ----------------------------------------------------

        if (n < 3)
            next


        # ----------------------------------------------------
        # Extract complete subtitle text.
        # Everything after timestamp belongs to the text.
        # ----------------------------------------------------

        text = ""

        for (i = 3; i <= n; i++) {

            if (text != "")
                text = text "\n"

            text = text lines[i]
        }


        # ----------------------------------------------------
        # EXACT adjacent duplicate
        # ----------------------------------------------------

        if (have_previous && text == previous_text)
            next


        # ----------------------------------------------------
        # KEEP SUBTITLE
        # ----------------------------------------------------

        count++

        print count
        print lines[2]

        for (i = 3; i <= n; i++)
            print lines[i]


        previous_text = text
        have_previous = 1
    }

    ' "$srt_new" > "$tmp_srt"

    rc=$?


    if (( rc != 0 )); then

        rm -f "$tmp_srt"

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_FAILED_TO_PROCESS_SRT)"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_FAILED_TO_REMOVE_ADJACENT_DUPLICATE_SUBTITLES)"

        return 1
    fi


    # ========================================================
    # CHECK FINAL RESULT
    # ========================================================

    if [[ ! -s "$tmp_srt" ]]; then

        rm -f "$tmp_srt"

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_PROCESSED_SRT_IS_EMPTY)"
        echo "$(t MP_GENERATE_SUBTITLES_ORIGINAL_SUBTITLES_WERE_PRESERVED)"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_PROCESSED_SUBTITLES_FINAL_SRT_WOULD_BE_EMPTY)"

        return 1
    fi


    # ========================================================
    # INSTALL FINAL SRT
    # ========================================================

    mv -f "$tmp_srt" "$srt_final" || {

        rm -f "$tmp_srt"

        echo
        echo "$(t MP_GENERATE_SUBTITLES_ERROR_CANNOT_CREATE)"
        echo "        $srt_final"
        echo

        mediapanel_log_error "$project" \
            "$(t MP_GENERATE_SUBTITLES_CANNOT_INSTALL_SUBTITLES_FINAL_SRT)"

        return 1
    }


    # ========================================================
    # STATISTICS
    # ========================================================

    local original_count
    local final_count
    local removed_count


    original_count="$(
        awk '
        BEGIN { RS="" }
        NF { count++ }
        END { print count+0 }
        ' "$srt_new"
    )"


    final_count="$(
        awk '
        BEGIN { RS="" }
        NF { count++ }
        END { print count+0 }
        ' "$srt_final"
    )"


    removed_count=$((original_count - final_count))


    # ========================================================
    # COMPLETED
    # ========================================================

    echo
    echo "=================================================="
    echo "$(t MP_GENERATE_SUBTITLES_SUBTITLE_GENERATION_COMPLETED)"
    echo "=================================================="
    echo "$(t MP_GENERATE_SUBTITLES_PROJECT "$project")"
    echo "$(t MP_GENERATE_SUBTITLES_MLT "$mlt")"
    echo "$(t MP_GENERATE_SUBTITLES_WAV_2 "$wav")"
    echo "$(t MP_GENERATE_SUBTITLES_ORIGINAL_SRT "$srt_new")"
    echo "$(t MP_GENERATE_SUBTITLES_BACKUP "$srt_bak")"
    echo "$(t MP_GENERATE_SUBTITLES_FINAL_SRT "$srt_final")"
    echo "$(t MP_GENERATE_SUBTITLES_ORIGINAL_SUBTITLES "$original_count")"
    echo "$(t MP_GENERATE_SUBTITLES_FINAL_SUBTITLES "$final_count")"
    echo "$(t MP_GENERATE_SUBTITLES_EXACT_REPEATS_REMOVED "$removed_count")"
    echo "=================================================="
    echo


    log_project "$project" \
        "Subtitle generation completed: $final_count subtitles, $removed_count exact adjacent duplicates removed"

    log_info "$(t MP_GENERATE_SUBTITLES_GENERATE_SUBTITLES_COMPLETED)"


    echo "$(t MP_GENERATE_SUBTITLES_OK_SUBTITLES_GENERATED)"
    echo "$(t MP_GENERATE_SUBTITLES_FINAL "$srt_final")"
    echo

    return 0
}

