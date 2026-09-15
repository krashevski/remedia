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

generate_subtitles() {

    local project
    project="$(require_active_project)" || return 1

    local project_path="$PROJECT_DIR/$project"

    # --------------------------------------------------------
    # PATHS
    # --------------------------------------------------------

    local mlt="$project_path/$project.mlt"

    local subtitles_dir="$project_path/subtitles"

    local wav="$subtitles_dir/${project}_subtitles.wav"

    local srt_new="$subtitles_dir/subtitles_new.srt"
    local srt_bak="$subtitles_dir/subtitles_new.srt.bak"
    local srt_final="$subtitles_dir/subtitles_final.srt"

    local model="$HOME/.var/app/org.shotcut.Shotcut/data/Meltytech/Shotcut/extensions/whispermodel/ggml-large-v3-q5_0.bin"
    
        # --------------------------------------------------------
    # SUBTITLE LANGUAGE
    #
    # CLI_LANGUAGE has the highest priority.
    # SUBTITLE_LANGUAGE can provide a configured default.
    # --------------------------------------------------------

    local language="${CLI_LANGUAGE:-${SUBTITLE_LANGUAGE:-}}"
    local language_name

    if [[ -z "$language" ]]; then

        if [[ "${CLI_NO_UI:-0}" == "1" ]]; then
            language="ru"
        else
            echo
            echo "Select subtitle language:"
            echo
            echo " 1) Russian"
            echo " 2) Kazakh"
            echo " 3) English"
            echo " 4) Auto detect"
            echo
            echo " 0) Cancel"
            echo

            local language_choice

            read -r -p "Choice [1-4, default 1]> " language_choice || {
                echo
                echo "[ERROR] Cannot read language selection"
                return 1
            }

            case "$language_choice" in
                ""|1)
                    language="ru"
                    ;;
                2)
                    language="kk"
                    ;;
                3)
                    language="en"
                    ;;
                4)
                    language="auto"
                    ;;
                0)
                    echo "[INFO] Subtitle generation cancelled"
                    return 0
                    ;;
                *)
                    echo "[ERROR] Invalid language selection"
                    return 1
                    ;;
            esac
        fi
    fi

    language="${language,,}"

    case "$language" in
        ru)
            language_name="Russian"
            ;;
        kk)
            language_name="Kazakh"
            ;;
        en)
            language_name="English"
            ;;
        auto)
            language_name="Auto detect"
            ;;
        [a-z][a-z]|[a-z][a-z][a-z])
            language_name="$language"
            ;;
        *)
            echo "[ERROR] Invalid Whisper language code: $language"
            return 1
            ;;
    esac

    mkdir -p "$subtitles_dir" || {
        echo "[ERROR] Cannot create subtitles directory:"
        echo "        $subtitles_dir"
        return 1
    }


    # ========================================================
    # HEADER
    # ========================================================

    echo
    echo "=================================================="
    echo " MEDIAPANEL GENERATE SUBTITLES"
    echo "=================================================="
    echo "Project : $project"
    echo "MLT     : $mlt"
    echo "WAV     : $wav"
    echo "Model   : $model"
    echo "Language: $language_name ($language)"
    echo "Output  : $srt_final"
    echo "=================================================="
    echo

    log_info "=== Generate Subtitles started ==="
    log_project "$project" "Subtitle generation started"


    # ========================================================
    # CHECK PROJECT
    # ========================================================

    if [[ ! -d "$project_path" ]]; then

        echo "[ERROR] Project directory not found:"
        echo "        $project_path"

        log_error "$project" \
            "Project directory not found: $project_path"

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

        echo "[ERROR] Main MLT project not found:"
        echo "        $mlt"

        log_error "$project" \
            "Main MLT project not found: $mlt"

        return 1
    fi

    if [[ ! -r "$mlt" ]]; then

        echo "[ERROR] Main MLT project is not readable:"
        echo "        $mlt"

        log_error "$project" \
            "Main MLT project is not readable: $mlt"

        return 1
    fi


    # ========================================================
    # CHECK WHISPER MODEL
    # ========================================================

    if [[ ! -f "$model" ]]; then

        echo "[ERROR] Whisper model not found:"
        echo "        $model"

        log_error "$project" \
            "Whisper model not found: $model"

        return 1
    fi

    if [[ ! -r "$model" ]]; then

        echo "[ERROR] Whisper model is not readable:"
        echo "        $model"

        log_error "$project" \
            "Whisper model is not readable: $model"

        return 1
    fi


    # ========================================================
    # FIND MELT
    # ========================================================

    local MELT_CMD=()
    local USE_FLATPAK_MELT=0

    if command -v melt >/dev/null 2>&1; then

        MELT_CMD=(melt)

        log_info "MLT engine: system melt"

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

        log_info "MLT engine: Shotcut Flatpak melt"
        log_info "Flatpak filesystem: $project_path:rw"

    else

        echo "[ERROR] melt not found."
        echo
        echo "Install MLT or Shotcut Flatpak."
        echo

        log_error "$project" "melt not found"

        return 1
    fi


    # ========================================================
    # CHECK MELT
    # ========================================================

    if ! "${MELT_CMD[@]}" -version >/dev/null 2>&1; then

        echo "[ERROR] melt is not executable"

        log_error "$project" "melt is not executable"

        return 1
    fi

    local melt_version

    melt_version="$(
        "${MELT_CMD[@]}" -version 2>&1 |
            head -n 1
    )"

    log_info "MLT: $melt_version"


    # ========================================================
    # FIND WHISPER CLI
    # ========================================================

    local WHISPER_CMD=()
    local USE_FLATPAK_WHISPER=0

    if command -v whisper-cli >/dev/null 2>&1; then

        WHISPER_CMD=(whisper-cli)

        log_info "Whisper: system whisper-cli"

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

        log_info "Whisper: Shotcut Flatpak whisper-cli"
        log_info "Flatpak filesystem: $project_path:rw"

    else

        echo "[ERROR] whisper-cli not found."
        echo
        echo "Expected Shotcut Flatpak whisper-cli."
        echo

        log_error "$project" "whisper-cli not found"

        return 1
    fi


    # ========================================================
    # CHECK WHISPER
    # ========================================================

    if ! "${WHISPER_CMD[@]}" --help >/dev/null 2>&1; then

        echo "[ERROR] whisper-cli is not executable"

        log_error "$project" \
            "whisper-cli is not executable"

        return 1
    fi


    # ========================================================
    # STEP 1
    # RENDER WAV FROM MAIN MLT
    # ========================================================

    echo
    echo "[1/4] Rendering audio from MLT..."
    echo

    log_info "Rendering subtitle WAV from: $mlt"

    if [[ -f "$wav" ]]; then

        echo "[WARN] Existing WAV will be replaced:"
        echo "       $wav"

        log_info "Removing existing subtitle WAV"

        rm -f "$wav" || {

            echo "[ERROR] Cannot remove existing WAV"

            log_error "$project" \
                "Cannot remove existing subtitle WAV"

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
        echo "[ERROR] Audio rendering failed."
        echo "        Exit code: $rc"
        echo

        log_error "$project" \
            "Subtitle WAV rendering failed (exit code $rc)"

        rm -f "$wav"

        return "$rc"
    fi


    # ========================================================
    # CHECK WAV
    # ========================================================

    if [[ ! -s "$wav" ]]; then

        echo
        echo "[ERROR] WAV was not created or is empty."
        echo

        log_error "$project" \
            "Subtitle WAV missing or empty"

        rm -f "$wav"

        return 1
    fi


    log_project "$project" \
        "Subtitle WAV created: $(basename "$wav")"

    echo
    echo "[OK] WAV created:"
    echo "     $wav"
    echo


    # ========================================================
    # STEP 2
    # WHISPER
    # ========================================================

    echo
    echo "[2/4] Running Whisper large-v3..."
    echo

    log_info "Whisper model: $model"
    log_info "Whisper language: $language_name ($language)"

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
        echo "[ERROR] Whisper transcription failed."
        echo "        Exit code: $rc"
        echo

        log_error "$project" \
            "Whisper transcription failed (exit code $rc)"

        rm -f "$srt_new"

        return "$rc"
    fi


    # ========================================================
    # CHECK SRT
    # ========================================================

    if [[ ! -s "$srt_new" ]]; then

        echo
        echo "[ERROR] Whisper did not create subtitles_new.srt."
        echo

        log_error "$project" \
            "Whisper produced no SRT"

        return 1
    fi


    log_project "$project" \
        "Whisper transcription completed: subtitles_new.srt"

    echo
    echo "[OK] Whisper transcription completed"
    echo "     $srt_new"
    echo


    # ========================================================
    # STEP 3
    # BACKUP
    # ========================================================

    echo
    echo "[3/4] Creating SRT backup..."
    echo


    cp -f "$srt_new" "$srt_bak" || {

        echo "[ERROR] Failed to create backup:"
        echo "        $srt_bak"

        log_error "$project" \
            "Failed to create subtitles_new.srt.bak"

        return 1
    }


    echo "[OK] Backup created:"
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
    echo "[4/4] Removing exact adjacent duplicate subtitles..."
    echo


    local tmp_srt

    tmp_srt="$(
        mktemp "${subtitles_dir}/.subtitles_final.XXXXXX"
    )" || {

        echo "[ERROR] Cannot create temporary SRT"

        log_error "$project" \
            "Cannot create temporary SRT file"

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
        echo "[ERROR] Failed to process SRT."
        echo

        log_error "$project" \
            "Failed to remove adjacent duplicate subtitles"

        return 1
    fi


    # ========================================================
    # CHECK FINAL RESULT
    # ========================================================

    if [[ ! -s "$tmp_srt" ]]; then

        rm -f "$tmp_srt"

        echo
        echo "[ERROR] Processed SRT is empty."
        echo "        Original subtitles were preserved."
        echo

        log_error "$project" \
            "Processed subtitles_final.srt would be empty"

        return 1
    fi


    # ========================================================
    # INSTALL FINAL SRT
    # ========================================================

    mv -f "$tmp_srt" "$srt_final" || {

        rm -f "$tmp_srt"

        echo
        echo "[ERROR] Cannot create:"
        echo "        $srt_final"
        echo

        log_error "$project" \
            "Cannot install subtitles_final.srt"

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
    echo " SUBTITLE GENERATION COMPLETED"
    echo "=================================================="
    echo "Project       : $project"
    echo "MLT           : $mlt"
    echo "WAV           : $wav"
    echo "Original SRT  : $srt_new"
    echo "Backup        : $srt_bak"
    echo "Final SRT     : $srt_final"
    echo "Original      : $original_count subtitles"
    echo "Final         : $final_count subtitles"
    echo "Exact repeats : $removed_count removed"
    echo "=================================================="
    echo


    log_project "$project" \
        "Subtitle generation completed: $final_count subtitles, $removed_count exact adjacent duplicates removed"

    log_info "Generate subtitles completed"


    echo "[OK] subtitles generated"
    echo "     Final: $srt_final"
    echo

    return 0
}

