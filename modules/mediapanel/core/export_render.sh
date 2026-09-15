#!/usr/bin/env bash
# modules/mediapanel/core/export_render.sh

# ============================================================
# EXPORT RENDER
# Основной MLT:
#   $PROJECT_DIR/$project/$project.mlt
#
# Результат:
#   $PROJECT_DIR/$project/export/${project}_final.mp4
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
    local src="$project_dir/edit"
    local dst="$project_dir/export"

    # Основной MLT проекта:
    local mlt="$project_dir/$project.mlt"

    mkdir -p "$dst" || {
        log_error "$project" "Cannot create export directory: $dst"
        return 1
    }

    log_info "=== Export Render started ==="
    log_project "$project" "Export render started"

    # --------------------------------------------------------
    # CHECK PROJECT
    # --------------------------------------------------------

    if [[ ! -d "$project_dir" ]]; then
        log_error "$project" "Project directory not found: $project_dir"
        echo
        echo "[ERROR] Project directory not found:"
        echo "        $project_dir"
        echo
        return 1
    fi

    if [[ ! -d "$src" ]]; then
        log_error "$project" "Edit directory not found: $src"
        echo
        echo "[ERROR] Edit directory not found:"
        echo "        $src"
        echo
        return 1
    fi

    if [[ ! -f "$mlt" ]]; then
        log_error "$project" "Main MLT project not found: $mlt"
        echo
        echo "[ERROR] Main MLT project not found:"
        echo "        $mlt"
        echo
        return 1
    fi

    if [[ ! -r "$mlt" ]]; then
        log_error "$project" "MLT project is not readable: $mlt"
        echo
        echo "[ERROR] MLT project is not readable:"
        echo "        $mlt"
        echo
        return 1
    fi

    # --------------------------------------------------------
    # OUTPUT
    # --------------------------------------------------------

    local out="$dst/${project}_final.mp4"

    log_info "Main MLT project: $mlt"
    log_info "Output: $out"

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

                if flatpak run \
                    --command=ffmpeg \
                    org.shotcut.Shotcut \
                    -hide_banner \
                    -encoders 2>/dev/null |
                    grep -q 'h264_nvenc'; then

                    nvenc_available=1

                fi

            elif command -v ffmpeg >/dev/null 2>&1; then

                if ffmpeg \
                    -hide_banner \
                    -encoders 2>/dev/null |
                    grep -q 'h264_nvenc'; then

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
    # BUILD MLT CONSUMER
    # --------------------------------------------------------

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

    # --------------------------------------------------------
    # REMOVE OLD OUTPUT
    # --------------------------------------------------------

    if [[ -f "$out" ]]; then

        log_warn "Removing existing export: $out"

        rm -f "$out" || {

            log_error "$project" \
                "Cannot remove existing output: $out"

            echo
            echo "[ERROR] Cannot remove existing output:"
            echo "        $out"
            echo

            return 1
        }

    fi

    # --------------------------------------------------------
    # RENDER INFORMATION
    # --------------------------------------------------------

    echo
    echo "=================================================="
    echo " MEDIAPANEL EXPORT RENDER"
    echo "=================================================="
    echo "Project : $project"
    echo "MLT     : $project.mlt"
    echo "Encoder : $encoder_mode"
    echo "Output  : $out"
    echo "=================================================="
    echo

    log_info "Rendering with $encoder_mode"

    # --------------------------------------------------------
    # RENDER
    # --------------------------------------------------------

    LC_ALL=C.UTF-8 \
    "${MELT_CMD[@]}" \
        -progress2 \
        "$mlt" \
        "${CONSUMER_ARGS[@]}"

    local rc=$?

    # --------------------------------------------------------
    # FAILURE
    # --------------------------------------------------------

    if (( rc != 0 )); then

        log_error "$project" \
            "MLT export failed (exit code $rc)"

        rm -f "$out"

        echo
        echo "=================================================="
        echo " [ERROR] EXPORT RENDER FAILED"
        echo "=================================================="
        echo "Project : $project"
        echo "Encoder : $encoder_mode"
        echo "Exit    : $rc"
        echo "=================================================="
        echo

        return "$rc"
    fi

    # --------------------------------------------------------
    # CHECK OUTPUT
    # --------------------------------------------------------

    if [[ ! -s "$out" ]]; then

        log_error "$project" \
            "Export completed but output file is missing or empty"

        rm -f "$out"

        echo
        echo "[ERROR] Export finished but output file is"
        echo "        missing or empty."
        echo

        return 1
    fi

    # --------------------------------------------------------
    # SUCCESS
    # --------------------------------------------------------

    pipeline_set "$project" "export" "done"

    log_project "$project" \
        "Export render completed: $(basename "$out") [$encoder_mode]"

    log_info "Export render completed"
    log_info "Encoder: $encoder_mode"
    log_info "Output: $out"

    echo
    echo "=================================================="
    echo " [OK] EXPORT RENDERED"
    echo "=================================================="
    echo "Encoder : $encoder_mode"
    echo "File    : $out"
    echo "Size    : $(du -h "$out" | cut -f1)"
    echo "=================================================="
    echo

    return 0
}
