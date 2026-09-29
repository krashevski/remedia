#!/usr/bin/env bash
# modules/mediapanel/core/export_render.sh

# ============================================================
# EXPORT RENDER
#
# Входные проекты:
#   video/${project}_video.mlt
#   short/${project}_short.mlt
#
# Результаты:
#   export/${project}_video_final.mp4
#   export/${project}_short_final.mp4
#
# CPU:
#   libx264, CRF 18, preset slow
#
# NVIDIA:
#   h264_nvenc, CQ 19, preset p5
#
# Shotcut Flatpak:
#   flatpak run --command=melt org.shotcut.Shotcut
# ============================================================

export_render() {

    local project
    project="$(require_active_project)" || return 1

    # --------------------------------------------------------
    # PROJECT DIRECTORIES
    # --------------------------------------------------------

    local project_dir="$PROJECT_DIR/$project"
    local video_dir="$project_dir/video"
    local short_dir="$project_dir/short"

    local -a files=()
    local -a selected_files=()

    if [[ ! -d "$project_dir" ]]; then
        log_error "$project" \
            "Project directory not found: $project_dir"

        echo
        echo "[ERROR] Project directory not found:"
        echo "        $project_dir"
        echo

        return 1
    fi

    mkdir -p "$video_dir" "$short_dir" || {
        log_error "$project" \
        "Cannot create video/short directories"
        return 1
    }

    # --------------------------------------------------------
    # FIND AVAILABLE MLT PROJECTS
    # --------------------------------------------------------
    mapfile -d '' -t files < <(
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

    if (( ${#files[@]} == 0 )); then
        log_error "$project" \
            "No Shotcut MLT projects found"

        echo
        echo "[ERROR] No Shotcut projects found in:"
        echo "        $video_dir"
        echo "        $short_dir"
        echo

        return 1
    fi

    if (( ${#files[@]} == 0 )); then
        log_error "$project" \
            "No Shotcut MLT projects found"

        echo
        echo "[ERROR] No Shotcut projects found."
        echo
        echo "Expected:"
        echo "  $video_mlt"
        echo "  $short_mlt"
        echo

        return 1
    fi

    # --------------------------------------------------------
    # SELECT MLT PROJECTS
    # --------------------------------------------------------

    echo
    echo "Available Shotcut projects:"
    echo "------------------------------------------------"

    local i=1
    local file
    local label

    for file in "${files[@]}"; do
        case "$file" in
            "$video_dir"/*)
                label="VIDEO"
                ;;
            "$short_dir"/*)
                label="SHORT"
                ;;
            *)
                label="MLT"
                ;;
        esac

        printf '%2d) [%-5s] %s\n' \
            "$i" \
            "$label" \
            "$(basename "$file")"

        ((i++))
    done

    echo "------------------------------------------------"
    echo "Select one or several projects."
    echo "Examples: 1   |   1 2   |   all"
    echo "Enter 0 to return."
    echo

    local selection=""
    read -rp "Selection: " selection

    selection="${selection//,/ }"

    if [[ "$selection" == "0" ]]; then
        return 0
    fi

    if [[ "$selection" == "all" ||
          "$selection" == "a" ]]; then

        selected_files=("${files[@]}")
    else
        local choice
        declare -A selected_numbers=()

        for choice in $selection; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]] ||
               (( choice < 1 ||
                  choice > ${#files[@]} )); then

                log_error "$project" \
                    "Invalid export selection: $choice"

                echo "[ERROR] Invalid selection: $choice"
                return 1
            fi

            # Prevent duplicate selections.
            if [[ -z "${selected_numbers[$choice]:-}" ]]; then
                selected_files+=(
                    "${files[$((choice - 1))]}"
                )
                selected_numbers["$choice"]=1
            fi
        done
    fi

    if (( ${#selected_files[@]} == 0 )); then
        log_error "$project" \
            "No MLT projects selected"
        return 1
    fi

    echo
    echo "Selected projects:"
    echo "------------------------------------------------"

    for file in "${selected_files[@]}"; do
        echo "• $(basename "$file")"
    done

    echo "------------------------------------------------"

    log_info "=== Export Render started ==="
    log_project "$project" "Export render started"

    # --------------------------------------------------------
    # FIND MELT
    # --------------------------------------------------------

    local -a MELT_CMD=()

    if command -v melt >/dev/null 2>&1; then

        MELT_CMD=(melt)

        log_info "MLT engine: system melt"

    elif command -v flatpak >/dev/null 2>&1 \
        && flatpak info org.shotcut.Shotcut >/dev/null 2>&1; then

        MELT_CMD=(
            flatpak
            run
            --command=melt
            org.shotcut.Shotcut
        )

        log_info "MLT engine: Shotcut Flatpak melt"

    else

        log_error "$project" "melt not found"

        echo
        echo "[ERROR] MLT render engine 'melt' is not available."
        echo

        return 1
    fi

    # --------------------------------------------------------
    # CHECK MELT
    # --------------------------------------------------------

    local melt_version

    melt_version="$(
        "${MELT_CMD[@]}" -version 2>&1 |
        head -n 1
    )"

    if [[ -z "$melt_version" ]]; then

        log_error "$project" "melt is not executable"

        echo
        echo "[ERROR] melt was found but could not be executed."
        echo

        return 1
    fi

    log_info "MLT: $melt_version"

    # --------------------------------------------------------
    # DETECT NVIDIA
    # --------------------------------------------------------

    local encoder="libx264"
    local encoder_mode="CPU"

    if command -v nvidia-smi >/dev/null 2>&1; then

        if nvidia-smi >/dev/null 2>&1; then

            log_info "NVIDIA GPU detected"

            # ------------------------------------------------
            # IMPORTANT:
            # Проверяем NVENC внутри Shotcut Flatpak.
            # Никакого пробного рендера проекта.
            # ------------------------------------------------

            local nvenc_available=0

            if [[ "${MELT_CMD[0]}" == "flatpak" ]]; then
                if flatpak run --command=ffmpeg org.shotcut.Shotcut \
                    -hide_banner -loglevel error \
                    -f lavfi -i testsrc2=size=640x360:rate=30 \
                    -t 1 -c:v h264_nvenc -f null - \
                    >/dev/null 2>&1; then
                    nvenc_available=1
                fi
            elif command -v ffmpeg >/dev/null 2>&1; then
                if ffmpeg \
                    -hide_banner -loglevel error \
                    -f lavfi -i testsrc2=size=640x360:rate=30 \
                    -t 1 -c:v h264_nvenc -f null - \
                    >/dev/null 2>&1; then
                    nvenc_available=1
                 fi
            fi

            if (( nvenc_available == 1 )); then

                encoder="h264_nvenc"
                encoder_mode="NVENC"

                log_info "h264_nvenc available inside MLT/Shotcut environment"

            else

                log_warn "h264_nvenc unavailable inside MLT/Shotcut environment"
                log_info "Using CPU encoder libx264"

            fi

        else

            log_warn "NVIDIA GPU detected but nvidia-smi failed"

        fi

    else

        log_info "NVIDIA tools not found; using CPU"

    fi

    # --------------------------------------------------------
    # RENDER SELECTED PROJECTS
    # --------------------------------------------------------

    local mlt
    local out
    local render_type
    local render_dir
    local rc
    local rendered=0

    for mlt in "${selected_files[@]}"; do

        local base_name

        base_name="$(basename "$mlt" .mlt)"

        case "$mlt" in
            "$video_dir"/*)
                 render_type="VIDEO"
                 render_dir="$video_dir"
                 out="$video_dir/${base_name}.mp4"
                 ;;

             "$short_dir"/*)
                  render_type="SHORT"
                  render_dir="$short_dir"
                  out="$short_dir/${base_name}.mp4"
                  ;;

              *)
                  log_error "$project" \
                  "Unknown MLT project type: $mlt"
                  return 1
                  ;;
          esac

        [[ -r "$mlt" ]] || {
            log_error "$project" \
                "MLT project is not readable: $mlt"
            return 1
        }

        # ----------------------------------------------------
        # BUILD MLT CONSUMER
        # ----------------------------------------------------

        local -a CONSUMER_ARGS

        if [[ "$encoder" == "h264_nvenc" ]]; then
            CONSUMER_ARGS=(
                -consumer
                "avformat:$out"
                vcodec=h264_nvenc
                acodec=aac
                ab=192k
                movflags=+faststart
                preset=p5
                cq=19
                pix_fmt=yuv420p
            )
        else
            CONSUMER_ARGS=(
                -consumer
                "avformat:$out"
                vcodec=libx264
                acodec=aac
                ab=192k
                movflags=+faststart
                crf=18
                preset=slow
                pix_fmt=yuv420p
            )
        fi

        # ----------------------------------------------------
        # REMOVE OLD OUTPUT
        # ----------------------------------------------------

        if [[ -f "$out" ]]; then
            log_warn "Removing existing export: $out"

            rm -f "$out" || {
                log_error "$project" \
                    "Cannot remove existing output: $out"
                return 1
            }
        fi

        # ----------------------------------------------------
        # RENDER INFORMATION
        # ----------------------------------------------------

        echo
        echo "=================================================="
        echo " MEDIAPANEL EXPORT RENDER"
        echo "=================================================="
        echo "Project : $project"
        echo "Type    : $render_type"
        echo "MLT     : $(basename "$mlt")"
        echo "Encoder : $encoder_mode"
        echo "Output  : $out"
        echo "=================================================="
        echo

        log_project "$project" \
            "$render_type export started: $(basename "$mlt")"

        # Running from the MLT directory also keeps relative
        # project resources associated with video/ or short/.
        (
            cd "$render_dir" || exit 1

            LC_ALL=C.UTF-8 \
            "${MELT_CMD[@]}" \
                -progress2 \
                "$mlt" \
                "${CONSUMER_ARGS[@]}"
        )

        rc=$?

        if (( rc != 0 )); then
            log_error "$project" \
                "$render_type export failed (exit code $rc)"

            rm -f "$out"

            echo
            echo "=================================================="
            echo " [ERROR] EXPORT RENDER FAILED"
            echo "=================================================="
            echo "Type    : $render_type"
            echo "Encoder : $encoder_mode"
            echo "Exit    : $rc"
            echo "=================================================="
            echo

            return "$rc"
        fi

        if [[ ! -s "$out" ]]; then
            log_error "$project" \
                "$render_type export is missing or empty"

            rm -f "$out"

            echo "[ERROR] Export file is missing or empty:"
            echo "        $out"

            return 1
        fi

        ((rendered += 1))

        log_project "$project" \
            "$render_type export completed: $(basename "$out") [$encoder_mode]"

        echo
        echo "=================================================="
        echo " [OK] EXPORT RENDERED"
        echo "=================================================="
        echo "Type    : $render_type"
        echo "Encoder : $encoder_mode"
        echo "File    : $out"
        echo "Size    : $(du -h "$out" | cut -f1)"
        echo "=================================================="
        echo
    done

    pipeline_set "$project" "export" "done"

    log_info "Export render completed"
    log_info "Rendered projects: $rendered"

    echo "[OK] rendered projects: $rendered"

    return 0
}
