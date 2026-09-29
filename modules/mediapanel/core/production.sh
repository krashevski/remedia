#!/usr/bin/env bash
# modules/mediapanel/core/production.sh

# =========================
# REQUIRE ACTIVE PROJECT
# =========================
require_active_project() {
    local p
    p="$(get_active_project)"

    [[ -n "$p" ]] || {
        echo "[ERROR] no active project selected"
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
        echo "[WARN] ingest missing (loose mode allowed)"
        return 0
    fi

    echo "[BLOCKED] ingest required"
    return 1
}

log_error() {
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

    echo "[Production] generating proxy for $project"

    log_project "$project" "Proxy generation started"

    local project_path="$PROJECT_DIR/$project"
    [[ -d "$project_path" ]] || {
        echo "[ERROR] project not found"
        log_error "$project" "No video files in $src"
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
        echo "[WARN] no video files found"
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
    echo "[OK] proxy generated for $project"
}


# =========================
# AUDIO CLEANUP
# =========================
audio_cleanup() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] audio cleanup for $project"
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
        echo "[WARN] no media files"
        log_error "$project" "No media files for audio cleanup"
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
            echo "[SKIP] exists"
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
    echo "[OK] audio cleaned"
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
        echo "[ERROR] failed to create video directory:"
        echo "        $video_dir"
        return 1
    }

    # -------------------------------------------------
    # Protect existing MLT project from overwrite
    # -------------------------------------------------

    if [[ -e "$mlt" || -L "$mlt" ]]; then
        echo "[INFO] video MLT project already exists:"
        echo "       $mlt"
        echo "[INFO] creation skipped to protect the existing project"
        return 2
    fi

    [[ -d "$project_path/edit" ]] || {
        echo "[ERROR] edit directory not found: $project_path/edit"
        return 1
    }

    command -v ffprobe >/dev/null 2>&1 || {
        echo "[ERROR] ffprobe not found"
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
        echo "[ERROR] no MP4 files found in $project_path/edit"
        return 1
    }

    echo "[Production] creating MLT from edit"
    echo "[Production] project: $project_name"
    echo "[Production] files:   $n"

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

    first_fps="$(
        ffprobe -v error \
            -select_streams v:0 \
            -show_entries stream=r_frame_rate \
            -of default=noprint_wrappers=1:nokey=1 \
            "$first_file"
    )"

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
        echo "[ERROR] invalid width detected: $mlt_width"
        return 1
    }

    [[ "$mlt_height" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid height detected: $mlt_height"
        return 1
    }

    [[ "$first_fps" =~ ^[0-9]+/[0-9]+$ ]] || {
        echo "[ERROR] invalid frame rate detected: $first_fps"
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
        echo "[ERROR] invalid FPS numerator: $mlt_fps_num"
        return 1
    }

    [[ "$mlt_fps_den" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid FPS denominator: $mlt_fps_den"
        return 1
    }

    [[ "$mlt_sar_num" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid SAR numerator: $mlt_sar_num"
        return 1
    }

    [[ "$mlt_sar_den" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid SAR denominator: $mlt_sar_den"
        return 1
    }

    [[ "$mlt_dar_num" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid DAR numerator: $mlt_dar_num"
        return 1
    }

    [[ "$mlt_dar_den" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid DAR denominator: $mlt_dar_den"
        return 1
    }

    (( mlt_fps_den > 0 )) || {
        echo "[ERROR] invalid FPS denominator: $mlt_fps_den"
        return 1
    }

    (( mlt_sar_den > 0 )) || {
        echo "[ERROR] invalid SAR denominator: $mlt_sar_den"
        return 1
    }

    (( mlt_dar_den > 0 )) || {
        echo "[ERROR] invalid DAR denominator: $mlt_dar_den"
        return 1
    }

    echo "[Production] profile from first clip:"
    echo "  resolution: ${mlt_width}x${mlt_height}"
    echo "  frame rate: ${mlt_fps_num}/${mlt_fps_den}"
    echo "  sample aspect: ${mlt_sar_num}:${mlt_sar_den}"
    echo "  display aspect: ${mlt_dar_num}:${mlt_dar_den}"

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
            echo "[ERROR] ffprobe failed: $file"
            return 1
        }

        [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
            echo "[ERROR] invalid duration: $file"
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

    echo "[Production] total duration: $total_tc"

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
        echo "[ERROR] failed to create MLT project"
        return 1
    }

    echo "[OK] video MLT project created: $mlt"
    echo "[OK] timeline clips: $n"
    echo "[OK] timeline duration: $total_tc"

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
        echo "[ERROR] failed to create short directory:"
        echo "        $short_dir"
        return 1
    }

    # -------------------------------------------------
    # Protect existing MLT project from overwrite
    # -------------------------------------------------

    if [[ -e "$mlt" || -L "$mlt" ]]; then
        echo "[INFO] short MLT project already exists:"
        echo "       $mlt"
        echo "[INFO] creation skipped to protect the existing project"
        return 2
    fi

    [[ -d "$project_path/scenes" ]] || {
        echo "[ERROR] scenes directory not found: $project_path/scenes"
        return 1
    }

    command -v ffprobe >/dev/null 2>&1 || {
        echo "[ERROR] ffprobe not found"
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
        echo "[ERROR] no MP4 files found in $project_path/scenes"
        return 1
    }

    echo "[Production] creating MLT from scenes"
    echo "[Production] project: $project_name"
    echo "[Production] files:   $n"

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

    first_fps="$(
        ffprobe -v error \
            -select_streams v:0 \
            -show_entries stream=r_frame_rate \
            -of default=noprint_wrappers=1:nokey=1 \
            "$first_file"
    )"

    [[ "$first_fps" =~ ^[0-9]+/[0-9]+$ ]] || {
        echo "[ERROR] invalid frame rate detected:"
        echo "        $first_fps"
        echo "[ERROR] first scene: $first_file"
        return 1
    }

    IFS='/' read -r \
        mlt_fps_num \
        mlt_fps_den <<< "$first_fps"

    [[ "$mlt_fps_num" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid FPS numerator: $mlt_fps_num"
        return 1
    }

    [[ "$mlt_fps_den" =~ ^[0-9]+$ ]] || {
        echo "[ERROR] invalid FPS denominator: $mlt_fps_den"
        return 1
    }

    (( mlt_fps_num > 0 )) || {
        echo "[ERROR] FPS numerator must be greater than zero"
        return 1
    }

    (( mlt_fps_den > 0 )) || {
        echo "[ERROR] FPS denominator must be greater than zero"
        return 1
    }

    echo "[Production] Short project profile:"
    echo "  resolution:    ${mlt_width}x${mlt_height}"
    echo "  frame rate:    ${mlt_fps_num}/${mlt_fps_den}"
    echo "  sample aspect: ${mlt_sar_num}:${mlt_sar_den}"
    echo "  display aspect: ${mlt_dar_num}:${mlt_dar_den}"
    echo "  FPS source:    $(basename "$first_file")"

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
            echo "[ERROR] ffprobe failed: $file"
            return 1
        }

        [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
            echo "[ERROR] invalid duration: $file"
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

    echo "[Production] total duration: $total_tc"

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
        echo "[ERROR] failed to create MLT project"
        return 1
    }

    echo "[OK] short MLT project created: $mlt"
    echo "[OK] playlist clips: $n"
    echo "[OK] timeline is empty"

    return 0
}

# =========================
# AUTO SYNC AUDIO
# =========================
auto_sync_audio() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] syncing audio for $project"
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
        echo "[WARN] no videos"
        log_error "$project" "No videos for sync"
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
            echo "[SKIP] no cleaned audio"
            log_error "$project" "Missing cleaned audio for $base"
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
    echo "[OK] audio synced"
}

# =========================
# AUTO SYNC AUDIO
# =========================
auto_sync_audio() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] syncing audio for $project"
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
        echo "[WARN] no videos"
        log_error "$project" "No videos for sync"
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
            echo "[SKIP] no cleaned audio"
            log_error "$project" "Missing cleaned audio for $base"
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
    echo "[OK] audio synced"
}

# =========================
# BATCH SCENE SPLIT
# =========================
batch_scene_split() {
#    require_ingest_done || return 1
    local project
    project="$(require_active_project)" || return 1

    echo "[Production] scene split for $project"
    log_project "$project" "Scene split started"

    local project_path="$PROJECT_DIR/$project"
    local src="$project_path/edit"
    local dst="$project_path/scenes"

    mkdir -p "$dst"

    mapfile -d '' videos < <(
        find "$src" -type f \( \
            -iname "*.mp4" -o \
            -iname "*.mov" -o \
            -iname "*.mkv" \
        \) -print0
    )

    local total=${#videos[@]}

    (( total == 0 )) && {
        echo "[WARN] no videos to split"
        log_project "$project" "No scene changes detected, fallback frame created"
        return 1
    }

    local count=1

    for video in "${videos[@]}"; do

        local name base outdir
        name=$(basename "$video")
        base="${name%.*}"
        outdir="$dst/$base"

        mkdir -p "$outdir"

        echo "[$count/$total] $name"

        ffmpeg -i "$video" \
            -c copy \
            -f segment \
            -segment_time 10 \
            -reset_timestamps 1 \
            "$outdir/${base}_scene_%03d.mp4"

        ((count++))
        log_project "$project" "Splitting scenes: $name"
    done

    log_project "$project" "Scene split completed"

    echo
    echo "[OK] scenes created"
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

        echo "[ERROR] failed to create Shotcut project directories"
        return 1
    }

    echo "[Production] creating Shotcut projects for $project"
    log_project "$project" "MLT creation started"

    create_mlt_from_edit "$project" "$project_path"
    rc_video=$?

    create_mlt_from_scenes "$project" "$project_path"
    rc_short=$?

    # Код 2 означает: MLT уже существует и защищён.
    if (( rc_video != 0 && rc_video != 2 )); then
        echo "[ERROR] failed to create video MLT project"
        return 1
    fi

    if (( rc_short != 0 && rc_short != 2 )); then
        echo "[ERROR] failed to create short MLT project"
        return 1
    fi

    log_project "$project" "Shotcut projects ready"
    echo "[OK] Shotcut projects are ready"
}

# =========================
# LAUNCH SHOTCUT
# =========================
launch_shotcut() {

    local project
    local project_dir
    local video_mlt
    local short_mlt
    local project_mlt
    local shotcut_dir
    local project_type
    local choice
    local rc

    project="$(require_active_project)" || return 1

    project_dir="$PROJECT_DIR/$project"

    video_mlt="$project_dir/video/${project}_video.mlt"
    short_mlt="$project_dir/short/${project}_short.mlt"

    echo
    echo "===================================================="
    echo "               LAUNCH SHOTCUT"
    echo "===================================================="
    echo
    echo "Project: $project"
    echo
    echo "Select Shotcut project:"
    echo

    if [[ -f "$video_mlt" ]]; then
        echo " 1) Video project"
        echo "    $video_mlt"
    else
        echo " 1) Video project [not found]"
    fi

    echo

    if [[ -f "$short_mlt" ]]; then
        echo " 2) Short project"
        echo "    $short_mlt"
    else
        echo " 2) Short project [not found]"
    fi

    echo
    echo " 0) Back"
    echo

    read -r -p "Select: " choice

    case "$choice" in
        1)
            project_mlt="$video_mlt"
            shotcut_dir="$project_dir/video"
            project_type="video"
            ;;
        2)
            project_mlt="$short_mlt"
            shotcut_dir="$project_dir/short"
            project_type="short"
            ;;
        0)
            return 0
            ;;
        *)
            echo "[ERROR] invalid selection"
            return 1
            ;;
    esac

    [[ -f "$project_mlt" ]] || {
        echo "[ERROR] MLT project not found:"
        echo "        $project_mlt"
        log_error "$project" "$project_type MLT project not found"
        return 1
    }

    echo
    echo "[Production] launching Shotcut for $project"
    echo "[Production] project type: $project_type"
    echo "[Production] opening MLT project:"
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
        echo "[ERROR] Shotcut not found"
        log_error "$project" "Shotcut not found"
        return 1
    fi

    if (( rc != 0 )); then
        echo "[ERROR] Shotcut exited with code: $rc"
        log_error "$project" \
            "Shotcut failed for $project_type project: exit $rc"
        return "$rc"
    fi

    log_project "$project" \
        "Shotcut closed: $project_type project"

    return 0
}
