#!/usr/bin/env bash
# modules/mediapanel/core/production.sh

# =========================
# REQUIRE ACTIVE PROJECT
# =========================
require_active_project() {
    local p
    p="$(get_active_project)"

    [[ -n "$p" ]] || {
        echo "$(t MP_PRODUCTION_ERROR_NO_ACTIVE_PROJECT_SELECTED)" >&2
        return 1
    }

    echo "$p"
}

require_ingest_done() {
    local project
    project="$(require_active_project)" || return 1

    local state
    state="$(pipeline_get "$project" "ingest" || echo "missing")"

    if [[ "$state" == "done" ]]; then
        return 0
    fi

    if [[ "${PIPELINE_STRICT:-0}" == "0" ]]; then
        echo "$(t MP_PRODUCTION_WARN_INGEST_MISSING_LOOSE_MODE_ALLOWED)"
        return 0
    fi

    echo "$(t MP_PRODUCTION_BLOCKED_INGEST_REQUIRED)"
    return 1
}

mediapanel_log_error() {
    local project="$1"
    local message="$2"

    log_project "$project" "[ERROR] $message"
}

log_project() {
    local project="$1"
    local message="$2"

    local project_path="$PROJECT_DIR/$project"
    local logfile="$project_path/.log"

    mkdir -p "$project_path"

    printf "[%s] [%s] %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$USER" \
        "$message" >> "$logfile"
}

# =========================
# GENERATE PROXY
# =========================
generate_proxy() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "$(t MP_PRODUCTION_PRODUCTION_GENERATING_PROXY_FOR "$project")"

    log_project "$project" "Proxy generation started"

    local project_path="$PROJECT_DIR/$project"
    [[ -d "$project_path" ]] || {
        echo "$(t MP_API_ERROR_PROJECT_NOT_FOUND)"
        mediapanel_log_error "$project" "$(t MP_PRODUCTION_NO_VIDEO_FILES_IN "$src")"
        return 1
    }

    local src="$project_path/media"

    local proxy_dir="$(storage_fast)/projects/$project"
    local dst="$proxy_dir/proxy"

    mkdir -p "$dst"

    shopt -s nullglob
    local files=("$src"/*.mp4)
    shopt -u nullglob

    (( ${#files[@]} == 0 )) && {
        echo "$(t MP_PRODUCTION_WARN_NO_VIDEO_FILES_FOUND)"
        return 1
    }

    for f in "${files[@]}"; do
        name=$(basename "$f")
        proxy="$dst/${name%.*}_proxy.mp4"

        ffmpeg -y -i "$f" \
            -vf scale=1280:-2 \
            -c:v libx264 -crf 28 \
            "$proxy"

        log_project "$project" "Processing: $name → $(basename "$proxy")"
    done

    log_project "$project" "Proxy generation completed"

    echo
    echo "$(t MP_PRODUCTION_OK_PROXY_GENERATED_FOR "$project")"
}


# =========================
# AUDIO CLEANUP
# =========================
audio_cleanup() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "$(t MP_PRODUCTION_PRODUCTION_AUDIO_CLEANUP_FOR "$project")"
    log_project "$project" "Audio cleanup started"

    local project_path="$PROJECT_DIR/$project"
    local src="$project_path/media"
    local dst="$project_path/audio"

    mkdir -p "$dst"

    mapfile -d '' files < <(
        find "$src" -type f \( \
            -iname "*.mp4" -o \
            -iname "*.mov" -o \
            -iname "*.mkv" -o \
            -iname "*.wav" -o \
            -iname "*.mp3" -o \
            -iname "*.m4a" \
        \) -print0
    )

    local total=${#files[@]}

    (( total == 0 )) && {
        echo "$(t MP_PRODUCTION_WARN_NO_MEDIA_FILES)"
        mediapanel_log_error "$project" "$(t MP_PRODUCTION_NO_MEDIA_FILES_FOR_AUDIO_CLEANUP)"
        return 1
    }

    local count=1

    for file in "${files[@]}"; do

        local name base output
        name=$(basename "$file")
        base="${name%.*}"
        output="$dst/${base}_clean.wav"

        echo "[$count/$total] $name"

        if [[ -f "$output" ]]; then
            echo "$(t MP_PRODUCTION_SKIP_EXISTS)"
            ((count++))
            continue
        fi

        ffmpeg -y -i "$file" \
            -vn \
            -af "adeclip,adeclick,acompressor=threshold=-18dB:ratio=2:attack=20:release=250:makeup=3,loudnorm=I=-16:TP=-1.5:LRA=11" \
            "$output"

        ((count++))
        log_project "$project" "Cleaning audio: $name"
    done

    log_project "$project" "Audio cleanup completed ($total files)"

    echo
    echo "$(t MP_PRODUCTION_OK_AUDIO_CLEANED)"
}

# Select a usable project rate without mistaking an FFmpeg timestamp-grid
# estimate (for example r_frame_rate=90000/1 on VFR footage) for playback FPS.
# Preserve a plausible r_frame_rate; fall back to avg_frame_rate otherwise.
# Do not guess 30 FPS if neither value is usable: callers report the existing
# translated invalid-frame-rate error before creating the MLT file.
mediapanel_mlt_frame_rate() {
    local probe_rates
    probe_rates="$(
        LC_ALL=C ffprobe -v error \
            -select_streams v:0 \
            -show_entries stream=r_frame_rate,avg_frame_rate \
            -of default=noprint_wrappers=1 \
            "$1"
    )" || return 1

    LC_ALL=C awk -F= '
        function usable(rate, a, n, d) {
            if (rate !~ /^[0-9]+\/[0-9]+$/) return 0
            split(rate, a, "/")
            n = a[1] + 0; d = a[2] + 0
            # MLT profile fields are integers. Limit automatic detection to
            # 1..240 FPS; absurd estimates must not become project profiles.
            return n > 0 && d > 0 && n <= 2147483647 && d <= 2147483647 && n/d >= 1 && n/d <= 240
        }
        function normalized(rate, a, n, d, x, y, rem) {
            split(rate, a, "/")
            n = a[1] + 0; d = a[2] + 0
            x = n; y = d
            while (y != 0) { rem = x % y; x = y; y = rem }
            return sprintf("%.0f/%.0f", n/x, d/x)
        }
        $1 == "r_frame_rate" { nominal = $2 }
        $1 == "avg_frame_rate" { average = $2 }
        END {
            if (usable(nominal)) print normalized(nominal)
            else if (usable(average)) print normalized(average)
            else exit 1
        }
    ' <<< "$probe_rates"
}

# =========================
# CREATE MLT FROM EDIT
# =========================
 create_mlt_from_edit() {

    local project_name="$1"
    local project_path="$2"
    local video_dir="$project_path/video"
    local mlt="$video_dir/${project_name}_video.mlt"

    mkdir -p "$video_dir" || {
        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_VIDEO_DIRECTORY)"
        echo "        $video_dir"
        return 1
    }

    # -------------------------------------------------
    # Protect existing MLT project from overwrite
    # -------------------------------------------------

    if [[ -e "$mlt" || -L "$mlt" ]]; then
        echo "$(t MP_PRODUCTION_INFO_VIDEO_MLT_PROJECT_ALREADY_EXISTS)"
        echo "       $mlt"
        echo "$(t MP_PRODUCTION_INFO_CREATION_SKIPPED_TO_PROTECT_THE_EXISTING_PROJECT)"
        return 2
    fi

    [[ -d "$project_path/edit" ]] || {
        echo "$(t MP_PRODUCTION_ERROR_EDIT_DIRECTORY_NOT_FOUND_EDIT "$project_path")"
        return 1
    }

    command -v ffprobe >/dev/null 2>&1 || {
        echo "$(t MP_PRODUCTION_ERROR_FFPROBE_NOT_FOUND)"
        return 1
    }

    local files=()
    local file
    local basename
    local duration
    local duration_tc
    local total_seconds="0"
    local total_tc
    local i
    local n

    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(
        find "$project_path/edit" -maxdepth 1 -type f \
            -iname '*.mp4' \
            -print0 | sort -z
    )

    n="${#files[@]}"

    (( n > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_NO_MP4_FILES_FOUND_IN_EDIT "$project_path")"
        return 1
    }

    echo "$(t MP_PRODUCTION_PRODUCTION_CREATING_MLT_FROM_EDIT)"
    echo "$(t MP_PRODUCTION_PRODUCTION_PROJECT "$project_name")"
    echo "$(t MP_PRODUCTION_PRODUCTION_FILES "$n")"

    # -------------------------------------------------
    # Detect project profile from first edit clip
    # -------------------------------------------------

    local first_file="${files[0]}"

    local mlt_width
    local mlt_height
    local first_fps
    local mlt_sar
    local mlt_dar

    local mlt_fps_num
    local mlt_fps_den
    local mlt_sar_num
    local mlt_sar_den
    local mlt_dar_num
    local mlt_dar_den

    mlt_width="$(
        ffprobe -v error \
            -select_streams v:0 \
            -show_entries stream=width \
            -of default=noprint_wrappers=1:nokey=1 \
            "$first_file"
    )"

    mlt_height="$(
        ffprobe -v error \
            -select_streams v:0 \
            -show_entries stream=height \
            -of default=noprint_wrappers=1:nokey=1 \
            "$first_file"
    )"

    first_fps="$(mediapanel_mlt_frame_rate "$first_file")" || first_fps=""

    mlt_sar="$(
        ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=sample_aspect_ratio \
        -of default=noprint_wrappers=1:nokey=1 \
        "$first_file"
    )"

    mlt_dar="$(
    ffprobe -v error \
        -select_streams v:0 \
        -show_entries stream=display_aspect_ratio \
        -of default=noprint_wrappers=1:nokey=1 \
        "$first_file"
    )"

    [[ "$mlt_width" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_WIDTH_DETECTED "$mlt_width")"
        return 1
    }

    [[ "$mlt_height" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_HEIGHT_DETECTED "$mlt_height")"
        return 1
    }

    [[ "$first_fps" =~ ^[0-9]+/[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FRAME_RATE_DETECTED "$first_fps")"
        return 1
    }

    # N/A is valid for ordinary square-pixel video.
    # Normalize missing SAR/DAR instead of failing MLT creation.

    if [[ "$mlt_sar" == "N/A" || -z "$mlt_sar" ]]; then
        mlt_sar="1:1"
    fi

    if [[ "$mlt_dar" == "N/A" || -z "$mlt_dar" ]]; then
        mlt_dar="${mlt_width}:${mlt_height}"
    fi

    IFS='/' read -r mlt_fps_num mlt_fps_den <<< "$first_fps"
    IFS=':' read -r mlt_sar_num mlt_sar_den <<< "$mlt_sar"
    IFS=':' read -r mlt_dar_num mlt_dar_den <<< "$mlt_dar"

    [[ "$mlt_fps_num" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FPS_NUMERATOR "$mlt_fps_num")"
        return 1
    }

    [[ "$mlt_fps_den" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FPS_DENOMINATOR "$mlt_fps_den")"
        return 1
    }

    [[ "$mlt_sar_num" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_SAR_NUMERATOR "$mlt_sar_num")"
        return 1
    }

    [[ "$mlt_sar_den" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_SAR_DENOMINATOR "$mlt_sar_den")"
        return 1
    }

    [[ "$mlt_dar_num" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_DAR_NUMERATOR "$mlt_dar_num")"
        return 1
    }

    [[ "$mlt_dar_den" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_DAR_DENOMINATOR "$mlt_dar_den")"
        return 1
    }

    (( mlt_fps_den > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FPS_DENOMINATOR "$mlt_fps_den")"
        return 1
    }

    (( mlt_sar_den > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_SAR_DENOMINATOR "$mlt_sar_den")"
        return 1
    }

    (( mlt_dar_den > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_DAR_DENOMINATOR "$mlt_dar_den")"
        return 1
    }

    echo "$(t MP_PRODUCTION_PRODUCTION_PROFILE_FROM_FIRST_CLIP)"
    echo "$(t MP_PRODUCTION_RESOLUTION_X "${mlt_width}" "${mlt_height}")"
    echo "$(t MP_PRODUCTION_FRAME_RATE "${mlt_fps_num}" "${mlt_fps_den}")"
    echo "$(t MP_PRODUCTION_SAMPLE_ASPECT "${mlt_sar_num}" "${mlt_sar_den}")"
    echo "$(t MP_PRODUCTION_DISPLAY_ASPECT "${mlt_dar_num}" "${mlt_dar_den}")"

    # -------------------------------------------------
    # Calculate total duration
    # -------------------------------------------------

    local durations=()

    for file in "${files[@]}"; do

        duration="$(
            ffprobe -v error \
                -show_entries format=duration \
                -of default=noprint_wrappers=1:nokey=1 \
                "$file"
        )" || {
            echo "$(t MP_PRODUCTION_ERROR_FFPROBE_FAILED "$file")"
            return 1
        }

        [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
            echo "$(t MP_PRODUCTION_ERROR_INVALID_DURATION "$file")"
            return 1
        }

        durations+=("$duration")

        total_seconds="$(
            awk -v a="$total_seconds" -v b="$duration" \
                'BEGIN { printf "%.6f", a + b }'
        )"

    done

    total_tc="$(
        awk -v d="$total_seconds" '
        BEGIN {
            h = int(d / 3600)
            d -= h * 3600

            m = int(d / 60)
            d -= m * 60

            s = int(d)
            ms = int((d - s) * 1000 + 0.5)

            if (ms >= 1000) {
                ms = 0
                s++
            }

            printf "%02d:%02d:%02d.%03d", h, m, s, ms
        }'
    )"

    echo "$(t MP_PRODUCTION_PRODUCTION_TOTAL_DURATION "$total_tc")"

    # -------------------------------------------------
    # Create MLT
    # -------------------------------------------------

    cat > "$mlt" <<EOF
<?xml version="1.0" standalone="no"?>
<mlt LC_NUMERIC="C"
     version="7.37.0"
     title="Shotcut version 26.2.26"
     producer="main_bin">

  <profile
    description="automatic"
    width="$mlt_width"
    height="$mlt_height"
    progressive="1"
    sample_aspect_num="$mlt_sar_num"
    sample_aspect_den="$mlt_sar_den"
    display_aspect_num="$mlt_dar_num"
    display_aspect_den="$mlt_dar_den"
    frame_rate_num="$mlt_fps_num"
    frame_rate_den="$mlt_fps_den"
    colorspace="709"/>

EOF

    # -------------------------------------------------
    # MAIN BIN CHAINS
    # -------------------------------------------------

    for i in "${!files[@]}"; do

        file="${files[$i]}"
        basename="$(basename "$file")"
        duration="${durations[$i]}"

        duration_tc="$(
            awk -v d="$duration" '
            BEGIN {
                h = int(d / 3600)
                d -= h * 3600

                m = int(d / 60)
                d -= m * 60

                s = int(d)
                ms = int((d - s) * 1000 + 0.5)

                if (ms >= 1000) {
                    ms = 0
                    s++
                }

                printf "%02d:%02d:%02d.%03d", h, m, s, ms
            }'
        )"

        cat >> "$mlt" <<EOF
  <chain id="chain$i" out="$duration_tc">
    <property name="length">$duration_tc</property>
    <property name="eof">pause</property>
    <property name="resource">../edit/$basename</property>
    <property name="mlt_service">avformat-novalidate</property>
    <property name="shotcut:disableProxy">1</property>
    <property name="audio_index">1</property>
    <property name="video_index">0</property>
  </chain>

EOF

    done

    # -------------------------------------------------
    # MAIN BIN
    # -------------------------------------------------

    cat >> "$mlt" <<EOF
  <playlist id="main_bin">
    <property name="xml_retain">1</property>
EOF

    for i in "${!files[@]}"; do

        file="${files[$i]}"
        duration="${durations[$i]}"

        duration_tc="$(
            awk -v d="$duration" '
            BEGIN {
                h = int(d / 3600)
                d -= h * 3600
                m = int(d / 60)
                d -= m * 60
                s = int(d)
                ms = int((d - s) * 1000 + 0.5)

                if (ms >= 1000) {
                    ms = 0
                    s++
                }

                printf "%02d:%02d:%02d.%03d", h, m, s, ms
            }'
        )"

        echo "    <entry producer=\"chain$i\" in=\"00:00:00.000\" out=\"$duration_tc\"/>" >> "$mlt"

    done

    cat >> "$mlt" <<EOF
  </playlist>

  <producer id="black"
            in="00:00:00.000"
            out="$total_tc">
    <property name="length">$total_tc</property>
    <property name="eof">pause</property>
    <property name="resource">0</property>
    <property name="aspect_ratio">1</property>
    <property name="mlt_service">color</property>
    <property name="mlt_image_format">rgba</property>
    <property name="set.test_audio">0</property>
  </producer>

  <playlist id="background">
    <entry producer="black"
           in="00:00:00.000"
           out="$total_tc"/>
  </playlist>

EOF

    # -------------------------------------------------
    # TIMELINE CHAINS
    # -------------------------------------------------

    for i in "${!files[@]}"; do

        local timeline_chain
        timeline_chain=$((n + i))

        file="${files[$i]}"
        basename="$(basename "$file")"
        duration="${durations[$i]}"

        duration_tc="$(
            awk -v d="$duration" '
            BEGIN {
                h = int(d / 3600)
                d -= h * 3600
                m = int(d / 60)
                d -= m * 60
                s = int(d)
                ms = int((d - s) * 1000 + 0.5)

                if (ms >= 1000) {
                    ms = 0
                    s++
                }

                printf "%02d:%02d:%02d.%03d", h, m, s, ms
            }'
        )"

        cat >> "$mlt" <<EOF
  <chain id="chain$timeline_chain" out="$duration_tc">
    <property name="length">$duration_tc</property>
    <property name="eof">pause</property>
    <property name="resource">../edit/$basename</property>
    <property name="mlt_service">avformat-novalidate</property>
    <property name="shotcut:disableProxy">1</property>
    <property name="audio_index">1</property>
    <property name="video_index">0</property>
  </chain>

EOF

    done

    # -------------------------------------------------
    # TIMELINE PLAYLIST
    # -------------------------------------------------

    cat >> "$mlt" <<EOF
  <playlist id="playlist0">
    <property name="shotcut:video">1</property>
    <property name="shotcut:name">V1</property>
EOF

    for i in "${!files[@]}"; do

        timeline_chain=$((n + i))
        duration="${durations[$i]}"

        duration_tc="$(
            awk -v d="$duration" '
            BEGIN {
                h = int(d / 3600)
                d -= h * 3600
                m = int(d / 60)
                d -= m * 60
                s = int(d)
                ms = int((d - s) * 1000 + 0.5)

                if (ms >= 1000) {
                    ms = 0
                    s++
                }

                printf "%02d:%02d:%02d.%03d", h, m, s, ms
            }'
        )"

        echo "    <entry producer=\"chain$timeline_chain\" in=\"00:00:00.000\" out=\"$duration_tc\"/>" >> "$mlt"

    done

    cat >> "$mlt" <<EOF
  </playlist>

  <tractor id="tractor0"
           title="Shotcut version 26.2.26"
           in="00:00:00.000"
           out="$total_tc">

    <property name="shotcut">1</property>
    <property name="shotcut:projectAudioChannels">2</property>
    <property name="shotcut:projectFolder">1</property>
    <property name="shotcut:processingMode">Native8Cpu</property>

    <track producer="background"/>
    <track producer="playlist0"/>

    <transition id="transition0">
      <property name="a_track">0</property>
      <property name="b_track">1</property>
      <property name="mlt_service">mix</property>
      <property name="always_active">1</property>
      <property name="sum">1</property>
    </transition>

    <transition id="transition1">
      <property name="a_track">0</property>
      <property name="b_track">1</property>
      <property name="compositing">0</property>
      <property name="distort">0</property>
      <property name="rotate_center">0</property>
      <property name="mlt_service">qtblend</property>
      <property name="threads">0</property>
      <property name="disable">1</property>
    </transition>

  </tractor>

</mlt>
EOF

    [[ -s "$mlt" ]] || {
        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_MLT_PROJECT)"
        return 1
    }

    echo "$(t MP_PRODUCTION_OK_VIDEO_MLT_PROJECT_CREATED "$mlt")"
    echo "$(t MP_PRODUCTION_OK_TIMELINE_CLIPS "$n")"
    echo "$(t MP_PRODUCTION_OK_TIMELINE_DURATION "$total_tc")"

    return 0
}

# =========================
# CREATE MLT FROM SCENES
# =========================
create_mlt_from_scenes() {

    local project_name="$1"
    local project_path="$2"
    local short_dir="$project_path/short"
    local mlt="$short_dir/${project_name}_short.mlt"

    mkdir -p "$short_dir" || {
        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_SHORT_DIRECTORY)"
        echo "        $short_dir"
        return 1
    }

    # -------------------------------------------------
    # Protect existing MLT project from overwrite
    # -------------------------------------------------

    if [[ -e "$mlt" || -L "$mlt" ]]; then
        echo "$(t MP_PRODUCTION_INFO_SHORT_MLT_PROJECT_ALREADY_EXISTS)"
        echo "       $mlt"
        echo "$(t MP_PRODUCTION_INFO_CREATION_SKIPPED_TO_PROTECT_THE_EXISTING_PROJECT)"
        return 2
    fi

    [[ -d "$project_path/scenes" ]] || {
        echo "$(t MP_PRODUCTION_ERROR_SCENES_DIRECTORY_NOT_FOUND_SCENES "$project_path")"
        return 1
    }

    command -v ffprobe >/dev/null 2>&1 || {
        echo "$(t MP_PRODUCTION_ERROR_FFPROBE_NOT_FOUND)"
        return 1
    }

    local files=()
    local file
    local basename
    local relative_path
    local resource
    local duration
    local duration_tc
    local total_seconds="0"
    local total_tc
    local i
    local n

    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(
        find "$project_path/scenes" -type f \
            -iname '*.mp4' \
            -print0 | sort -z
    )

    n="${#files[@]}"

    (( n > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_NO_MP4_FILES_FOUND_IN_SCENES "$project_path")"
        return 1
    }

    echo "$(t MP_PRODUCTION_PRODUCTION_CREATING_MLT_FROM_SCENES)"
    echo "$(t MP_PRODUCTION_PRODUCTION_PROJECT "$project_name")"
    echo "$(t MP_PRODUCTION_PRODUCTION_FILES "$n")"

    # -------------------------------------------------
    # Create UHD 4K profile using FPS from first scene
    # -------------------------------------------------

    local first_file="${files[0]}"

    # Fixed UHD 4K landscape profile.
    # Shotcut Output Reframe will later convert it to 9:16.
    local mlt_width=3840
    local mlt_height=2160

    local mlt_sar_num=1
    local mlt_sar_den=1

    local mlt_dar_num=16
    local mlt_dar_den=9

    local first_fps
    local mlt_fps_num
    local mlt_fps_den

    first_fps="$(mediapanel_mlt_frame_rate "$first_file")" || first_fps=""

    [[ "$first_fps" =~ ^[0-9]+/[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FRAME_RATE_DETECTED_2)"
        echo "        $first_fps"
        echo "$(t MP_PRODUCTION_ERROR_FIRST_SCENE "$first_file")"
        return 1
    }

    IFS='/' read -r \
        mlt_fps_num \
        mlt_fps_den <<< "$first_fps"

    [[ "$mlt_fps_num" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FPS_NUMERATOR "$mlt_fps_num")"
        return 1
    }

    [[ "$mlt_fps_den" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_FPS_DENOMINATOR "$mlt_fps_den")"
        return 1
    }

    (( mlt_fps_num > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_FPS_NUMERATOR_MUST_BE_GREATER_THAN_ZERO)"
        return 1
    }

    (( mlt_fps_den > 0 )) || {
        echo "$(t MP_PRODUCTION_ERROR_FPS_DENOMINATOR_MUST_BE_GREATER_THAN_ZERO)"
        return 1
    }

    echo "$(t MP_PRODUCTION_PRODUCTION_SHORT_PROJECT_PROFILE)"
    echo "$(t MP_PRODUCTION_RESOLUTION_X_2 "${mlt_width}" "${mlt_height}")"
    echo "$(t MP_PRODUCTION_FRAME_RATE_2 "${mlt_fps_num}" "${mlt_fps_den}")"
    echo "$(t MP_PRODUCTION_SAMPLE_ASPECT "${mlt_sar_num}" "${mlt_sar_den}")"
    echo "$(t MP_PRODUCTION_DISPLAY_ASPECT "${mlt_dar_num}" "${mlt_dar_den}")"
    echo "$(t MP_PRODUCTION_FPS_SOURCE "$(basename "$first_file")")"

    # -------------------------------------------------
    # Calculate total duration
    # -------------------------------------------------

    local durations=()

    for file in "${files[@]}"; do

        duration="$(
            ffprobe -v error \
                -show_entries format=duration \
                -of default=noprint_wrappers=1:nokey=1 \
                "$file"
        )" || {
            echo "$(t MP_PRODUCTION_ERROR_FFPROBE_FAILED "$file")"
            return 1
        }

        [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
            echo "$(t MP_PRODUCTION_ERROR_INVALID_DURATION "$file")"
            return 1
        }

        durations+=("$duration")

        total_seconds="$(
            awk -v a="$total_seconds" -v b="$duration" \
                'BEGIN { printf "%.6f", a + b }'
        )"

    done

    total_tc="$(
        awk -v d="$total_seconds" '
        BEGIN {
            h = int(d / 3600)
            d -= h * 3600

            m = int(d / 60)
            d -= m * 60

            s = int(d)
            ms = int((d - s) * 1000 + 0.5)

            if (ms >= 1000) {
                ms = 0
                s++
            }

            printf "%02d:%02d:%02d.%03d", h, m, s, ms
        }'
    )"

    echo "$(t MP_PRODUCTION_PRODUCTION_TOTAL_DURATION "$total_tc")"

    # -------------------------------------------------
    # Create MLT
    # -------------------------------------------------

    cat > "$mlt" <<EOF
<?xml version="1.0" standalone="no"?>
<mlt LC_NUMERIC="C"
     version="7.37.0"
     title="Shotcut version 26.2.26"
     producer="main_bin">

  <profile
    description="automatic"
    width="$mlt_width"
    height="$mlt_height"
    progressive="1"
    sample_aspect_num="$mlt_sar_num"
    sample_aspect_den="$mlt_sar_den"
    display_aspect_num="$mlt_dar_num"
    display_aspect_den="$mlt_dar_den"
    frame_rate_num="$mlt_fps_num"
    frame_rate_den="$mlt_fps_den"
    colorspace="709"/>

EOF

    # -------------------------------------------------
    # MAIN BIN CHAINS
    # -------------------------------------------------

    for i in "${!files[@]}"; do

    file="${files[$i]}"
    basename="$(basename "$file")"
    relative_path="${file#"$project_path/scenes/"}"
    resource="../scenes/$relative_path"
    duration="${durations[$i]}"

    duration_tc="$(
        awk -v d="$duration" '
        BEGIN {
            h = int(d / 3600)
            d -= h * 3600

            m = int(d / 60)
            d -= m * 60

            s = int(d)
            ms = int((d - s) * 1000 + 0.5)

            if (ms >= 1000) {
                ms = 0
                s++
            }

            printf "%02d:%02d:%02d.%03d", h, m, s, ms
        }'
    )"

    cat >> "$mlt" <<EOF
  <chain id="chain$i" out="$duration_tc">
    <property name="length">$duration_tc</property>
    <property name="eof">pause</property>
    <property name="resource">$resource</property>
    <property name="mlt_service">avformat-novalidate</property>
    <property name="shotcut:disableProxy">1</property>
    <property name="audio_index">1</property>
    <property name="video_index">0</property>
  </chain>

EOF

    done

    # -------------------------------------------------
    # MAIN BIN
    # -------------------------------------------------

    cat >> "$mlt" <<EOF
  <playlist id="main_bin">
    <property name="xml_retain">1</property>
EOF

    for i in "${!files[@]}"; do

        file="${files[$i]}"
        duration="${durations[$i]}"

        duration_tc="$(
            awk -v d="$duration" '
            BEGIN {
                h = int(d / 3600)
                d -= h * 3600
                m = int(d / 60)
                d -= m * 60
                s = int(d)
                ms = int((d - s) * 1000 + 0.5)

                if (ms >= 1000) {
                    ms = 0
                    s++
                }

                printf "%02d:%02d:%02d.%03d", h, m, s, ms
            }'
        )"

        echo "    <entry producer=\"chain$i\" in=\"00:00:00.000\" out=\"$duration_tc\"/>" >> "$mlt"

    done

    cat >> "$mlt" <<EOF
  </playlist>

  <producer id="black"
            in="00:00:00.000"
            out="$total_tc">
    <property name="length">$total_tc</property>
    <property name="eof">pause</property>
    <property name="resource">0</property>
    <property name="aspect_ratio">1</property>
    <property name="mlt_service">color</property>
    <property name="mlt_image_format">rgba</property>
    <property name="set.test_audio">0</property>
  </producer>

  <playlist id="background">
    <entry producer="black"
           in="00:00:00.000"
           out="$total_tc"/>
  </playlist>

  <!-- Empty Shotcut timeline -->
  <playlist id="playlist0">
    <property name="shotcut:video">1</property>
    <property name="shotcut:name">V1</property>
  </playlist>

  <tractor id="tractor0"
           title="Shotcut version 26.2.26"
           in="00:00:00.000"
           out="$total_tc">

    <property name="shotcut">1</property>
    <property name="shotcut:projectAudioChannels">2</property>
    <property name="shotcut:projectFolder">1</property>
    <property name="shotcut:processingMode">Native8Cpu</property>

    <track producer="background"/>
    <track producer="playlist0"/>

    <transition id="transition0">
      <property name="a_track">0</property>
      <property name="b_track">1</property>
      <property name="mlt_service">mix</property>
      <property name="always_active">1</property>
      <property name="sum">1</property>
    </transition>

    <transition id="transition1">
      <property name="a_track">0</property>
      <property name="b_track">1</property>
      <property name="compositing">0</property>
      <property name="distort">0</property>
      <property name="rotate_center">0</property>
      <property name="mlt_service">qtblend</property>
      <property name="threads">0</property>
      <property name="disable">1</property>
    </transition>

  </tractor>

</mlt>
EOF

    [[ -s "$mlt" ]] || {
        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_MLT_PROJECT)"
        return 1
    }

    echo "$(t MP_PRODUCTION_OK_SHORT_MLT_PROJECT_CREATED "$mlt")"
    echo "$(t MP_PRODUCTION_OK_PLAYLIST_CLIPS "$n")"
    echo "$(t MP_PRODUCTION_OK_TIMELINE_IS_EMPTY)"

    return 0
}

# =========================
# AUTO SYNC AUDIO
# =========================
auto_sync_audio() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "$(t MP_PRODUCTION_PRODUCTION_SYNCING_AUDIO_FOR "$project")"
    log_project "$project" "Audio sync started"

    local project_path="$PROJECT_DIR/$project"
    local video_dir="$project_path/media"
    local audio_dir="$project_path/audio"
    local output_dir="$project_path/edit"

    mkdir -p "$output_dir"

    mapfile -d '' videos < <(
        find "$video_dir" -type f \( \
            -iname "*.mp4" -o \
            -iname "*.mov" -o \
            -iname "*.mkv" \
        \) -print0
    )

    local total=${#videos[@]}

    (( total == 0 )) && {
        echo "$(t MP_PRODUCTION_WARN_NO_VIDEOS)"
        mediapanel_log_error "$project" "$(t MP_PRODUCTION_NO_VIDEOS_FOR_SYNC)"
        return 1
    }

    local count=1

    for video in "${videos[@]}"; do

        local name base clean_audio output
        name=$(basename "$video")
        base="${name%.*}"

        clean_audio="$audio_dir/${base}_clean.wav"
        output="$output_dir/${base}_sync.mp4"

        echo "[$count/$total] $name"

        if [[ ! -f "$clean_audio" ]]; then
            echo "$(t MP_PRODUCTION_SKIP_NO_CLEANED_AUDIO)"
            mediapanel_log_error "$project" "$(t MP_PRODUCTION_MISSING_CLEANED_AUDIO_FOR "$base")"
            ((count++))
            continue
        fi

        ffmpeg -y \
            -i "$video" \
            -i "$clean_audio" \
            -map 0:v:0 \
            -map 1:a:0 \
            -c:v copy \
            -c:a aac -b:a 192k \
            "$output"

        ((count++))
        log_project "$project" "Sync: $name"
    done

    log_project "$project" "Audio sync completed"

    echo
    echo "$(t MP_PRODUCTION_OK_AUDIO_SYNCED)"
}

# =========================
# AUTO SYNC AUDIO
# =========================
auto_sync_audio() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "$(t MP_PRODUCTION_PRODUCTION_SYNCING_AUDIO_FOR "$project")"
    log_project "$project" "Audio sync started"

    local project_path="$PROJECT_DIR/$project"
    local video_dir="$project_path/media"
    local audio_dir="$project_path/audio"
    local output_dir="$project_path/edit"

    mkdir -p "$output_dir"

    mapfile -d '' videos < <(
        find "$video_dir" -type f \( \
            -iname "*.mp4" -o \
            -iname "*.mov" -o \
            -iname "*.mkv" \
        \) -print0
    )

    local total=${#videos[@]}

    (( total == 0 )) && {
        echo "$(t MP_PRODUCTION_WARN_NO_VIDEOS)"
        mediapanel_log_error "$project" "$(t MP_PRODUCTION_NO_VIDEOS_FOR_SYNC)"
        return 1
    }

    local count=1

    for video in "${videos[@]}"; do

        local name base clean_audio output
        name=$(basename "$video")
        base="${name%.*}"

        clean_audio="$audio_dir/${base}_clean.wav"
        output="$output_dir/${base}_sync.mp4"

        echo "[$count/$total] $name"

        if [[ ! -f "$clean_audio" ]]; then
            echo "$(t MP_PRODUCTION_SKIP_NO_CLEANED_AUDIO)"
            mediapanel_log_error "$project" "$(t MP_PRODUCTION_MISSING_CLEANED_AUDIO_FOR "$base")"
            ((count++))
            continue
        fi

        ffmpeg -y \
            -i "$video" \
            -i "$clean_audio" \
            -map 0:v:0 \
            -map 1:a:0 \
            -c:v copy \
            -c:a aac -b:a 192k \
            "$output"

        ((count++))
        log_project "$project" "Sync: $name"
    done

    log_project "$project" "Audio sync completed"

    echo
    echo "$(t MP_PRODUCTION_OK_AUDIO_SYNCED)"
}

# =========================
# BATCH SCENE SPLIT
# =========================
batch_scene_split() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "$(t MP_PRODUCTION_PRODUCTION_SCENE_SPLIT_FOR "$project")"
    log_project "$project" "Scene split started (content detection)"

    local project_path="$PROJECT_DIR/$project"
    local src="$project_path/edit"
    local dst="$project_path/scenes"
    local threshold="${MP_SCENE_THRESHOLD:-0.30}"
    local min_duration="${MP_SCENE_MIN_SECONDS:-2}"
    local threads="${MP_SCENE_THREADS:-2}"
    local tool
    for tool in ffmpeg ffprobe awk; do
        command -v "$tool" >/dev/null 2>&1 || {
            printf '[ERROR] %s\n' "$tool" >&2
            log_project "$project" "Scene split: required command missing: $tool"
            return 1
        }
    done
    # Validate before interpolating configuration into FFmpeg filter expressions.
    if ! LC_ALL=C awk -v t="$threshold" -v m="$min_duration" -v n="$threads" '
        BEGIN {
            number="^[0-9]+([.][0-9]+)?$"
            exit !(t ~ number && t > 0 && t < 1 &&
                   m ~ number && m > 0 && n ~ /^[1-9][0-9]*$/ && n <= 64)
        }'; then
        printf '[ERROR] MP_SCENE_THRESHOLD / MP_SCENE_MIN_SECONDS / MP_SCENE_THREADS\n' >&2
        return 1
    fi
    [[ -d "$src" ]] || {
        echo "$(t MP_PRODUCTION_ERROR_EDIT_DIRECTORY_NOT_FOUND_EDIT "$project_path")" >&2
        return 1
    }
    mkdir -p "$dst" || return 1

    local -a videos=()
    mapfile -d '' videos < <(
        find "$src" -type f \( \
            -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \
        \) -print0 | sort -z
    )
    local total=${#videos[@]}
    if (( total == 0 )); then
        echo "$(t MP_PRODUCTION_WARN_NO_VIDEOS_TO_SPLIT)"
        log_project "$project" "No videos found in edit directory"
        return 1
    fi

    local count=0 failures=0 video name base pattern_base outdir work duration cuts fps delta
    for video in "${videos[@]}"; do
        count=$((count + 1))
        name="$(basename "$video")"
        base="${name%.*}"
        pattern_base="${base//%/%%}"
        outdir="$dst/$base"
        printf '[%s/%s] %s\n' "$count" "$total" "$name"

        # Existing scenes may already be referenced by a Shotcut project.
        # Refuse replacement, including files with the same stem/other extension.
        if [[ -e "$outdir" || -L "$outdir" ]]; then
            printf '[ERROR] %s\n' "$outdir" >&2
            log_project "$project" "Scene split refused: destination already exists: $outdir (move it before rerunning)"
            failures=$((failures + 1))
            continue
        fi

        # Keep incomplete outputs outside scenes/, where MLT discovery runs.
        work="$(mktemp -d "$project_path/.scene-split-XXXXXXXX")" || return 1
        if ! duration="$(LC_ALL=C ffprobe -v error -select_streams v:0 \
            -show_entries stream=duration -of default=nw=1:nk=1 "$video")" ||
            ! LC_ALL=C awk -v d="$duration" 'BEGIN { exit !(d ~ /^[0-9]+([.][0-9]+)?$/ && d > 0) }'; then
            duration="$(LC_ALL=C ffprobe -v error -show_entries format=duration \
                -of default=nw=1:nk=1 "$video")"
        fi
        if ! LC_ALL=C awk -v d="$duration" 'BEGIN { exit !(d ~ /^[0-9]+([.][0-9]+)?$/ && d > 0) }'; then
            echo "$(t MP_PRODUCTION_ERROR_INVALID_DURATION "$video")" >&2
            rm -rf -- "$work"
            failures=$((failures + 1))
            continue
        fi

        # Decode every frame, but compare reduced images to limit analysis cost.
        # Normalize timestamps so detected times and the encoder share origin 0.
        if ! LC_ALL=C ffmpeg -hide_banner -nostdin -v error -threads "$threads" \
            -i "$video" -an -sn -dn -filter_threads 1 \
            -vf "setpts=PTS-STARTPTS,scale=320:-2,select='gt(scene,$threshold)',metadata=mode=print:file=-" \
            -f null - > "$work/detected.txt"; then
            printf '[ERROR] %s\n' "$name" >&2
            log_project "$project" "Scene detection failed: $name"
            rm -rf -- "$work"
            failures=$((failures + 1))
            continue
        fi

        # Suppress clusters of detections and very short leading/trailing pieces.
        cuts="$(LC_ALL=C awk -v min="$min_duration" -v end="$duration" '
            /pts_time:/ {
                value=$0; sub(/^.*pts_time:/, "", value); sub(/[[:space:]].*$/, "", value)
                if (value ~ /^[0-9]+([.][0-9]+)?$/ && value-last >= min && end-value >= min) {
                    printf "%s%.6f", sep, value; sep=","; last=value
                }
            }
        ' "$work/detected.txt")"
        log_project "$project" "Scene detection: $name; threshold=$threshold; min_seconds=$min_duration; cuts=${cuts:-none}"

        local rc=0
        if [[ -n "$cuts" ]]; then
            fps="$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate \
                -of default=nw=1:nk=1 "$video")"
            delta="$(LC_ALL=C awk -v fps="$fps" 'BEGIN {
                split(fps, a, "/"); if (a[1]+0 > 0 && a[2]+0 > 0) printf "%.9f", a[2]/(2*a[1]); else print "0"
            }')"
            # Re-encode in one pass and force keyframes at detected cuts.
            # Stream copy cannot guarantee boundaries at non-keyframes.
            LC_ALL=C ffmpeg -hide_banner -nostdin -v warning -n -threads "$threads" \
                -i "$video" -map 0:v:0 -map '0:a:0?' -sn -dn \
                -vf 'setpts=PTS-STARTPTS' -af 'asetpts=PTS-STARTPTS' \
                -filter_threads 1 -c:v libx264 -threads:v "$threads" \
                -preset veryfast -crf 18 -pix_fmt yuv420p \
                -force_key_frames "$cuts" -c:a aac -b:a 192k \
                -f segment -segment_times "$cuts" -segment_time_delta "$delta" \
                -reset_timestamps 1 -segment_format_options movflags=+faststart \
                "$work/${pattern_base}_scene_%03d.mp4" || rc=$?
        else
            # A continuous take stays whole; remux without generation loss.
            LC_ALL=C ffmpeg -hide_banner -nostdin -v warning -n \
                -i "$video" -map 0:v:0 -map '0:a:0?' -sn -dn \
                -c copy -movflags +faststart "$work/${base}_scene_000.mp4" || rc=$?
        fi

        if (( rc != 0 )) || [[ ! -s "$work/${base}_scene_000.mp4" ]]; then
            printf '[ERROR] %s\n' "$name" >&2
            log_project "$project" "Scene split failed: $name (FFmpeg exit $rc)"
            rm -rf -- "$work"
            failures=$((failures + 1))
            continue
        fi
        rm -f -- "$work/detected.txt"
        # -T prevents nesting if a competing invocation creates the destination.
        if ! mv -T -n -- "$work" "$outdir" || [[ -d "$work" ]]; then
            printf '[ERROR] %s\n' "$outdir" >&2
            log_project "$project" "Scene split: could not publish output: $outdir"
            rm -rf -- "$work"
            failures=$((failures + 1))
            continue
        fi
        log_project "$project" "Scene split completed: $name"
    done

    if (( failures > 0 )); then
        log_project "$project" "Scene split incomplete: $failures of $total files failed or were protected"
        return 1
    fi
    log_project "$project" "Scene split completed"
    echo
    echo "$(t MP_PRODUCTION_OK_SCENES_CREATED)"
}

# =========================
# Build initial MLT project from prepared edit videos
# =========================
create_mlt() {

    local project
    local project_path
    local rc_video=0
    local rc_short=0

    project="$(require_active_project)" || return 1
    project_path="$PROJECT_DIR/$project"

    mkdir -p \
        "$project_path/video" \
        "$project_path/short" || {

        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_SHOTCUT_PROJECT_DIRECTORIES)"
        return 1
    }

    echo "$(t MP_PRODUCTION_PRODUCTION_CREATING_SHOTCUT_PROJECTS_FOR "$project")"
    log_project "$project" "MLT creation started"

    create_mlt_from_edit "$project" "$project_path"
    rc_video=$?

    create_mlt_from_scenes "$project" "$project_path"
    rc_short=$?

    # Код 2 означает: MLT уже существует и защищён.
    if (( rc_video != 0 && rc_video != 2 )); then
        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_VIDEO_MLT_PROJECT)"
        return 1
    fi

    if (( rc_short != 0 && rc_short != 2 )); then
        echo "$(t MP_PRODUCTION_ERROR_FAILED_TO_CREATE_SHORT_MLT_PROJECT)"
        return 1
    fi

    log_project "$project" "Shotcut projects ready"
    echo "$(t MP_PRODUCTION_OK_SHOTCUT_PROJECTS_ARE_READY)"
}

# =========================
# LAUNCH SHOTCUT
# =========================
launch_shotcut() {

    local project
    local project_dir
    local project_mlt
    local shotcut_dir
    local project_type
    local choice
    local rc
    local i
    local file

    local -a mlt_files=()
    local -a mlt_types=()

    project="$(require_active_project)" || return 1

    project_dir="$PROJECT_DIR/$project"

    # --------------------------------------------------------
    # COLLECT VIDEO MLT PROJECTS
    # --------------------------------------------------------

    if [[ -d "$project_dir/video" ]]; then
        while IFS= read -r -d '' file; do
            mlt_files+=("$file")
            mlt_types+=("video")
        done < <(
            find "$project_dir/video" \
                -maxdepth 1 \
                -type f \
                -name '*.mlt' \
                -print0 |
            sort -z
        )
    fi

    # --------------------------------------------------------
    # COLLECT SHORT MLT PROJECTS
    # --------------------------------------------------------

    if [[ -d "$project_dir/short" ]]; then
        while IFS= read -r -d '' file; do
            mlt_files+=("$file")
            mlt_types+=("short")
        done < <(
            find "$project_dir/short" \
                -maxdepth 1 \
                -type f \
                -name '*.mlt' \
                -print0 |
            sort -z
        )
    fi

    # --------------------------------------------------------
    # MENU
    # --------------------------------------------------------

    echo
    echo "===================================================="
    echo "$(t MP_PRODUCTION_LAUNCH_SHOTCUT)"
    echo "===================================================="
    echo
    echo "$(t MP_EXPORT_PROJECT "$project")"
    echo

    if (( ${#mlt_files[@]} == 0 )); then
        echo "$(t MP_PRODUCTION_WARN_NO_SHOTCUT_MLT_PROJECTS_FOUND)"
        echo
        echo "$(t MP_PRODUCTION_CHECKED)"
        echo "  $project_dir/video"
        echo "  $project_dir/short"

        log_project \
            "$project" \
            "No Shotcut MLT projects found"

        return 0
    fi

    echo "$(t MP_EXPORT_RENDER_AVAILABLE_SHOTCUT_PROJECTS)"
    echo

    for i in "${!mlt_files[@]}"; do

        if [[ "${mlt_types[$i]}" == "video" ]]; then
            printf " %d) [%s] %s\n" \
                "$((i + 1))" \
                "$(t MP_KIND_VIDEO)" \
                "$(basename "${mlt_files[$i]}")"
        else
            printf " %d) [%s] %s\n" \
                "$((i + 1))" \
                "$(t MP_KIND_SHORT)" \
                "$(basename "${mlt_files[$i]}")"
        fi

    done

    echo
    echo "$(t MP_PRODUCTION_0_BACK)"
    echo

    read -r -p "$(t MP_PRODUCTION_SELECT)" choice

    # --------------------------------------------------------
    # VALIDATE SELECTION
    # --------------------------------------------------------

    [[ "$choice" =~ ^[0-9]+$ ]] || {
        echo "$(t MP_PRODUCTION_ERROR_INVALID_SELECTION)"
        return 1
    }

    if (( choice == 0 )); then
        return 0
    fi

    if (( choice < 1 || choice > ${#mlt_files[@]} )); then
        echo "$(t MP_PRODUCTION_ERROR_INVALID_SELECTION)"
        return 1
    fi

    # Array indexes start from 0.
    i=$((choice - 1))

    project_mlt="${mlt_files[$i]}"
    project_type="${mlt_types[$i]}"
    shotcut_dir="$(dirname "$project_mlt")"

    # --------------------------------------------------------
    # OPEN PROJECT
    # --------------------------------------------------------

    echo
    echo "$(t MP_PRODUCTION_PRODUCTION_LAUNCHING_SHOTCUT_FOR "$project")"
    echo "$(t MP_PRODUCTION_PRODUCTION_PROJECT_TYPE "$project_type")"
    echo "$(t MP_PRODUCTION_PRODUCTION_OPENING_MLT_PROJECT)"
    echo "  $project_mlt"

    log_project \
        "$project" \
        "Opening $project_type MLT project: $project_mlt"

    if command -v flatpak >/dev/null 2>&1; then

        (
            cd "$shotcut_dir" || exit 1
            flatpak run org.shotcut.Shotcut "$project_mlt"
        )

        rc=$?

    elif command -v shotcut >/dev/null 2>&1; then

        (
            cd "$shotcut_dir" || exit 1
            shotcut "$project_mlt"
        )

        rc=$?

    else
        echo "$(t MP_PRODUCTION_ERROR_SHOTCUT_NOT_FOUND)"
        mediapanel_log_error "$project" "$(t MP_PRODUCTION_SHOTCUT_NOT_FOUND)"
        return 1
    fi

    # --------------------------------------------------------
    # RESULT
    # --------------------------------------------------------

    if (( rc != 0 )); then
        echo "$(t MP_PRODUCTION_ERROR_SHOTCUT_EXITED_WITH_CODE "$rc")"

        log_error \
            "$project" \
            "Shotcut failed for $project_type project: $project_mlt, exit $rc"

        return "$rc"
    fi

    log_project \
        "$project" \
        "Shotcut closed: $project_type project: $project_mlt"

    return 0
}
