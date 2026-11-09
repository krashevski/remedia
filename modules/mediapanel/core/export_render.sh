#!/usr/bin/env bash
# modules/mediapanel/core/export_render.sh

# ============================================================
# EXPORT RENDER
#
# Входные проекты:
#   video/${project}_video.mlt
#   ...
#   short/${project}_short.mlt
#   ...
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

# Prepare a render-only copy; never rewrite the Shotcut project.
export_prepare_render_mlt() {
    python3 - "$1" "$2" <<'PY_MLT'
import os
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
import re

source = Path(sys.argv[1]).absolute()
target = Path(sys.argv[2])
try:
    tree = ET.parse(source)
    root = tree.getroot()
    declared = root.get("root", "")
    xml_base = Path(declared).expanduser() if declared else source.parent
    if not xml_base.is_absolute():
        xml_base = source.parent / xml_base

    def resolve_results(value):
        path = Path(value).expanduser()
        if path.is_absolute():
            candidates = [path]
        else:
            candidates = [xml_base / path, source.parent / path,
                          Path.home() / path]
        matches = {p.resolve() for p in candidates if p.is_file()}
        # A moved project can retain an old relative directory prefix.
        # Only use its local basename when the full paths found nothing.
        if not matches and not path.is_absolute():
            local = source.parent / path.name
            if local.is_file():
                matches.add(local.resolve())
        if len(matches) != 1:
            reason = "not found" if not matches else "ambiguous"
            raise ValueError(f"Stabilization file {reason}: {value}")
        resolved = matches.pop()
        if resolved.stat().st_size == 0 or not os.access(resolved, os.R_OK):
            raise ValueError(f"Stabilization file empty or unreadable: {resolved}")
        return resolved

    for filt in root.iter("filter"):
        props = {p.get("name"): p for p in filt.findall("property")}
        def value(name):
            prop = props.get(name)
            return prop.text if prop is not None and prop.text else ""
        if value("mlt_service") != "vidstab":
            continue
        if value("disable") == "1":
            continue
        results = value("results")
        if not results:
            raise ValueError("Stabilization analysis missing; run Analyze in Shotcut "
                             "and save the project before exporting")
        resolved = resolve_results(results)
        props["results"].text = str(resolved)
        if "filename" in props:
            props["filename"].text = str(resolved)
        print(f"[INFO] Stabilization results: {resolved}")
    # The Shotcut Reframe output filter requires export-time conversion.
    # Capture a static rectangle as metadata; reject animated/unknown formats
    # rather than silently exporting a landscape SHORT.
    reframes = []
    for tractor in root.iter("tractor"):
        for filt in tractor.findall("filter"):
            props = {p.get("name"): (p.text or "") for p in filt.findall("property")}
            if props.get("shotcut:filter") == "reframe" and props.get("disable") != "1":
                reframes.append(props)
    if len(reframes) > 1:
        raise ValueError("Multiple enabled Reframe filters; cannot select safely")
    if reframes:
        value = reframes[0].get("rect", "").strip()
        if not re.fullmatch(r"-?\d+(?:\.\d+)?(?:px)?[ ,]+-?\d+(?:\.\d+)?(?:px)?[ ,]+\d+(?:\.\d+)?(?:px)?[ ,]+\d+(?:\.\d+)?(?:px)?(?:[ ,]+(?:[01](?:\.\d+)?))?", value):
            raise ValueError("Reframe has keyframes or unsupported rectangle: " + value +
                             "; use Shotcut export for animated Reframe")
        nums = [float(x.removesuffix("px")) for x in re.split(r"[ ,]+", value)[:4]]
        x, y, w, h = map(round, nums)
        profile = root.find("profile")
        if profile is None:
            raise ValueError("Missing MLT profile for Reframe")
        pw, ph = int(profile.get("width", "0")), int(profile.get("height", "0"))
        if not (pw > 0 and ph > 0 and w > 0 and h > 0
                and w % 2 == 0 and h % 2 == 0
                and x >= 0 and y >= 0 and x + w <= pw and y + h <= ph):
            raise ValueError(f"Invalid Reframe crop: {x},{y} {w}x{h} in {pw}x{ph}")
        print(f"[REFRAME] {x} {y} {w} {h} / profile {pw}x{ph}")
    tree.write(target, encoding="utf-8", xml_declaration=True)
except (OSError, ET.ParseError, ValueError) as exc:
    print(f"[ERROR] {exc}", file=sys.stderr)
    sys.exit(1)
PY_MLT
}

export_nvenc_help() {
    echo
    echo "$(t MP_EXPORT_RENDER_WARNING_SHOTCUT_FLATPAK_NVENC_IS_UNAVAILABLE)"
    echo "$(t MP_EXPORT_RENDER_MEDIAPANEL_SYSTEM_STATUS)"
    echo "$(t MP_EXPORT_RENDER_6_SHOTCUT_FLATPAK_NVENC_DOCTOR)"
    echo "$(t MP_EXPORT_RENDER_7_SHOTCUT_FLATPAK_NVENC_HEAL)"
    echo "$(t MP_EXPORT_RENDER_CLI_REMEDIA_SYSTEM_NVIDIA_FLATPAK_NVENC_DOCTOR)"
    echo "$(t MP_EXPORT_RENDER_CLI_REMEDIA_SYSTEM_NVIDIA_FLATPAK_NVENC_HEAL)"
    echo "$(t MP_EXPORT_RENDER_INFO_NO_AUTOMATIC_REPAIRS_WILL_BE_PERFORMED)"
    echo
}

# Read an enabled static Reframe rectangle from Output (tractor).
# Do not guess keyframed motion. The preparation step validates geometry.
export_reframe_geometry() {
    python3 - "$1" <<'PY_REF'
import sys, re, xml.etree.ElementTree as ET
root=ET.parse(sys.argv[1]).getroot()
for tractor in root.iter('tractor'):
    for filt in tractor.findall('filter'):
        props={p.get('name'): (p.text or '') for p in filt.findall('property')}
        if props.get('shotcut:filter') == 'reframe' and props.get('disable') != '1':
            rect=props.get('rect','').strip()
            vals=[int(round(float(x.removesuffix('px')))) for x in re.split(r'[ ,]+',rect)[:4]]
            profile=root.find('profile')
            if profile is None:
                raise SystemExit('Missing MLT profile')
            source_w=int(profile.get('width', '0'))
            source_h=int(profile.get('height', '0'))
            if source_w <= 0 or source_h <= 0:
                raise SystemExit('Invalid MLT profile dimensions')
            print(*vals, source_w, source_h)
            sys.exit(0)
PY_REF
}


# Build a Shotcut-style export wrapper: the nested project is a producer,
# and its affine crop is applied inside that producer, never via melt -attach.
export_create_reframe_wrapper() {
    python3 - "$1" "$2" <<'PY_WRAPPER'
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source, destination = (Path(p).resolve() for p in sys.argv[1:])
try:
    root = ET.parse(source).getroot()
    profile = root.find('profile')
    if profile is None:
        raise ValueError('Missing source profile')
    sw, sh = (int(profile.get(k, '0')) for k in ('width', 'height'))
    fn = int(profile.get('frame_rate_num', '0'))
    fd = int(profile.get('frame_rate_den', '0'))
    if min(sw, sh, fn, fd) <= 0:
        raise ValueError('Invalid source profile dimensions or frame rate')

    reframes = []
    for tractor in root.iter('tractor'):
        for filt in tractor.findall('filter'):
            props = {p.get('name'): (p.text or '') for p in filt.findall('property')}
            if props.get('shotcut:filter') == 'reframe' and props.get('disable') != '1':
                reframes.append(props)
    if len(reframes) != 1:
        raise ValueError(f'Expected one enabled Reframe, got {len(reframes)}')
    rect = reframes[0].get('rect', '').strip().split()
    if len(rect) not in (4, 5) or (len(rect) == 5 and float(rect[4]) != 1):
        raise ValueError('Only static Reframe rectangles are supported')
    x, y, w, h = [int(round(float(v.removesuffix('px')))) for v in rect[:4]]
    if not (0 <= x and 0 <= y and w > 0 and h > 0
            and w % 2 == 0 and h % 2 == 0 and x + w <= sw and y + h <= sh):
        raise ValueError('Invalid Reframe crop')

    # Render the timeline, not the full duration of an underlying source clip.
    # Shotcut may renumber tractors when transitions/tracks are edited.
    # Select the editable timeline by its marker, never by a fixed id.
    tractors = root.findall('tractor')
    timelines = [tractor for tractor in tractors
                 if (tractor.findtext("property[@name='shotcut']") or '').strip() == '1']
    if len(timelines) == 1:
        timeline = timelines[0]
    elif not timelines and len(tractors) == 1:
        # Support older/minimal MLT projects without the Shotcut marker.
        timeline = tractors[0]
    else:
        raise ValueError('Cannot select timeline safely: '
                         f'{len(timelines)} Shotcut timelines, {len(tractors)} tractors')
    end = timeline.get('out', '')
    if re.fullmatch(r'\d+:\d\d:\d\d\.\d+', end):
        hh, mm, ss = end.split(':')
        frames = round((int(hh)*3600 + int(mm)*60 + float(ss)) * fn / fd) + 1
    elif re.fullmatch(r'\d+', end):
        frames = int(end) + 1
    else:
        raise ValueError(f'Unsupported timeline end: {end!r}')
    if frames <= 0:
        raise ValueError('Empty timeline')

    gcd = math.gcd(w, h)
    wrap = ET.Element('mlt', {
        'LC_NUMERIC': 'C', 'producer': 'producer0', 'in': '0',
        'out': str(frames - 1), 'version': root.get('version', '7.41.0')
    })
    ET.SubElement(wrap, 'profile', {
        'description': 'Remedia Shotcut Reframe', 'width': str(w), 'height': str(h),
        'progressive': profile.get('progressive', '1'),
        'frame_rate_num': str(fn), 'frame_rate_den': str(fd),
        'colorspace': profile.get('colorspace', '709'),
        'display_aspect_num': str(w // gcd), 'display_aspect_den': str(h // gcd),
        'sample_aspect_num': '1', 'sample_aspect_den': '1'
    })
    producer = ET.SubElement(wrap, 'producer', {
        'id': 'producer0', 'in': '0', 'out': str(frames - 1)
    })
    for key, value in (
        ('length', str(frames)), ('eof', 'pause'),
        # Absolute path WITHOUT xml: prefix: verified with Shotcut Flatpak melt.
        ('resource', str(source)), ('aspect_ratio', '1'),
        ('mlt_service', 'consumer')
    ):
        ET.SubElement(producer, 'property', {'name': key}).text = value
    filt = ET.SubElement(producer, 'filter', {'id': 'filter0'})
    for key, value in (
        ('background', 'colour:0'), ('mlt_service', 'affine'),
        ('transition.valign', 'middle'), ('transition.halign', 'center'),
        ('transition.rect', f'-{x} -{y} {sw} {sh} 1')
    ):
        ET.SubElement(filt, 'property', {'name': key}).text = value
    ET.ElementTree(wrap).write(destination, encoding='utf-8', xml_declaration=True)
    print(f'[REFRAME] Source {sw}x{sh}; crop ({x},{y}) {w}x{h}; '
          f'output {w}x{h}; frames {frames}')
except (ValueError, OSError, ET.ParseError) as exc:
    print(f'[ERROR] Reframe wrapper: {exc}', file=sys.stderr)
    sys.exit(1)
PY_WRAPPER
}

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
        mediapanel_log_error "$project" \
            "$(t MP_EXPORT_PROJECT_DIRECTORY_NOT_FOUND "$project_dir")"

        echo
        echo "$(t MP_EXPORT_RENDER_ERROR_PROJECT_DIRECTORY_NOT_FOUND)"
        echo "        $project_dir"
        echo

        return 1
    fi

    mkdir -p "$video_dir" "$short_dir" || {
        mediapanel_log_error "$project" \
        "$(t MP_EXPORT_RENDER_CANNOT_CREATE_VIDEO_SHORT_DIRECTORIES)"
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
        mediapanel_log_error "$project" \
            "$(t MP_EXPORT_RENDER_NO_SHOTCUT_MLT_PROJECTS_FOUND)"

        echo
        echo "$(t MP_EXPORT_RENDER_ERROR_NO_SHOTCUT_PROJECTS_FOUND_IN)"
        echo "        $video_dir"
        echo "        $short_dir"
        echo

        return 1
    fi

    # --------------------------------------------------------
    # SELECT MLT PROJECTS
    # --------------------------------------------------------

    echo
    echo "$(t MP_EXPORT_RENDER_AVAILABLE_SHOTCUT_PROJECTS)"
    echo "------------------------------------------------"

    local i=1
    local file
    local label

    for file in "${files[@]}"; do
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
    echo "$(t MP_EXPORT_RENDER_SELECT_ONE_OR_SEVERAL_PROJECTS)"
    echo "$(t MP_EXPORT_EXAMPLES_1_1_2_ALL)"
    echo
    echo -e "$(t MP_EXPORT_RENDER_ENTER_0_TO_RETURN "${COLOR_YELLOW}" "${COLOR_RESET}")"
    echo

    local selection=""
    read -rp "$(t MP_EXPORT_SELECTION)" selection

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

                mediapanel_log_error "$project" \
                    "$(t MP_EXPORT_RENDER_INVALID_EXPORT_SELECTION "$choice")"

                echo "$(t MP_EXPORT_RENDER_ERROR_INVALID_SELECTION "$choice")"
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
        mediapanel_log_error "$project" \
            "$(t MP_EXPORT_RENDER_NO_MLT_PROJECTS_SELECTED)"
        return 1
    fi

    echo
    echo "$(t MP_EXPORT_RENDER_SELECTED_PROJECTS)"
    echo "------------------------------------------------"

    for file in "${selected_files[@]}"; do
        echo "• $(basename "$file")"
    done

    echo "------------------------------------------------"

    log_info "$(t MP_EXPORT_RENDER_EXPORT_RENDER_STARTED)"
    log_project "$project" "Export render started"

    # --------------------------------------------------------
    # FIND MELT
    # --------------------------------------------------------

    local -a MELT_CMD=()

    if command -v melt >/dev/null 2>&1; then

        MELT_CMD=(melt)

        log_info "$(t MP_EXPORT_RENDER_MLT_ENGINE_SYSTEM_MELT)"

    elif command -v flatpak >/dev/null 2>&1 \
        && flatpak info org.shotcut.Shotcut >/dev/null 2>&1; then

        MELT_CMD=(
            flatpak
            run
            --command=melt
            org.shotcut.Shotcut
        )

        log_info "$(t MP_EXPORT_RENDER_MLT_ENGINE_SHOTCUT_FLATPAK_MELT)"

    else

        mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_MELT_NOT_FOUND)"

        echo
        echo "$(t MP_EXPORT_RENDER_ERROR_MLT_RENDER_ENGINE_MELT_IS_NOT_AVAILABLE)"
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

        mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_MELT_IS_NOT_EXECUTABLE)"

        echo
        echo "$(t MP_EXPORT_RENDER_ERROR_MELT_WAS_FOUND_BUT_COULD_NOT_BE_EXECUTED)"
        echo

        return 1
    fi

    log_info "$(t MP_EXPORT_RENDER_MLT "$melt_version")"

    # --------------------------------------------------------
    # DETECT NVIDIA
    # --------------------------------------------------------

    local encoder="libx264"
    local encoder_mode="CPU"

    if command -v nvidia-smi >/dev/null 2>&1; then

        if nvidia-smi >/dev/null 2>&1; then

            log_info "$(t MP_EXPORT_RENDER_NVIDIA_GPU_DETECTED)"

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

                log_info "$(t MP_EXPORT_RENDER_H264_NVENC_AVAILABLE_INSIDE_MLT_SHOTCUT_ENVIRONMENT)"

            else

                log_warn "$(t MP_EXPORT_RENDER_H264_NVENC_UNAVAILABLE_INSIDE_MLT_SHOTCUT_ENVIRONMENT)"
                log_info "$(t MP_EXPORT_RENDER_USING_CPU_ENCODER_LIBX264)"
                if [[ "${MELT_CMD[0]}" == "flatpak" ]]; then
                    export_nvenc_help
                fi

            fi

        else

            log_warn "$(t MP_EXPORT_RENDER_NVIDIA_GPU_DETECTED_BUT_NVIDIA_SMI_FAILED)"

        fi

    else

        log_info "$(t MP_EXPORT_RENDER_NVIDIA_TOOLS_NOT_FOUND_USING_CPU)"

    fi

    # --------------------------------------------------------
    # RENDER SELECTED PROJECTS
    # --------------------------------------------------------

    local mlt
    local out
    local render_type
    local render_dir
    local rc
    local render_mlt
    local rendered=0
    local render_wrapper render_input
    local render_target

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
                  mediapanel_log_error "$project" \
                  "$(t MP_EXPORT_RENDER_UNKNOWN_MLT_PROJECT_TYPE "$mlt")"
                  return 1
                  ;;
          esac

        [[ -r "$mlt" ]] || {
            mediapanel_log_error "$project" \
                "$(t MP_EXPORT_RENDER_MLT_PROJECT_IS_NOT_READABLE "$mlt")"
            return 1
        }

        # Render to a temporary MP4; leave existing successful output intact.
        render_target="$(mktemp "$render_dir/.remedia-output-XXXXXXXX.mp4")" || return 1

        # ----------------------------------------------------
        # BUILD MLT CONSUMER
        # ----------------------------------------------------

        local -a CONSUMER_ARGS

        if [[ "$encoder" == "h264_nvenc" ]]; then
            CONSUMER_ARGS=(
                -consumer
                "avformat:$render_target"
                real_time=-1
                buffer=5
                vcodec=h264_nvenc
                acodec=aac
                ab=192k
                movflags=+faststart
                preset=p5
                cq=19
                pix_fmt=yuv420p
                progressive=1
            )
        else
            CONSUMER_ARGS=(
                -consumer
                "avformat:$render_target"
                real_time=-1
                buffer=5
                vcodec=libx264
                acodec=aac
                ab=192k
                movflags=+faststart
                crf=18
                preset=slow
                pix_fmt=yuv420p
                progressive=1
            )
        fi

        # Validate stabilization before touching any existing MP4.
        command -v python3 >/dev/null 2>&1 || {
            mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_PYTHON3_IS_REQUIRED_FOR_MLT_PATH_VALIDATION)"
            return 1
        }

        render_mlt="$(mktemp "$render_dir/.remedia-render-XXXXXX.xml")" || return 1
        if ! export_prepare_render_mlt "$mlt" "$render_mlt"; then
            rm -f -- "$render_mlt" "$render_target"
            mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_STABILIZATION_REFRAME_VALIDATION_FAILED "$mlt")"
            return 1
        fi

        # ----------------------------------------------------
        # SHOTCUT REFRAME -> NESTED MLT WRAPPER (static crop)
        # ----------------------------------------------------
        local reframe_geometry=""
        reframe_geometry="$(export_reframe_geometry "$render_mlt")" || {
            rm -f -- "$render_mlt" "$render_target"
            echo "$(t MP_EXPORT_RENDER_ERROR_CANNOT_READ_SHOTCUT_REFRAME_GEOMETRY)"
            return 1
        }
        render_wrapper=""
        render_input="$render_mlt"
        if [[ -n "$reframe_geometry" ]]; then
            render_wrapper="$(mktemp "$render_dir/.remedia-wrapper-XXXXXXXX.xml")" || {
                rm -f -- "$render_mlt" "$render_target"
                return 1
            }
            if ! export_create_reframe_wrapper "$render_mlt" "$render_wrapper"; then
                rm -f -- "$render_wrapper" "$render_mlt" "$render_target"
                mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_CANNOT_PREPARE_REFRAME_WRAPPER "$mlt")"
                return 1
            fi
            render_input="$render_wrapper"
            # Mirror the successful wrapper test (no extra MLT buffer override).
            # Keep ordinary VIDEO/SHORT encoding options unchanged.
            local -a wrapper_consumer_args=()
            local arg
            for arg in "${CONSUMER_ARGS[@]}"; do
                [[ "$arg" == buffer=5 ]] || wrapper_consumer_args+=("$arg")
            done
            CONSUMER_ARGS=("${wrapper_consumer_args[@]}")
        elif [[ "$render_type" == "SHORT" ]]; then
            echo "$(t MP_EXPORT_RENDER_WARNING_THIS_SHORT_PROJECT_HAS_NO_ENABLED_OUTPUT_REFRAME_FILTER)"
            echo "$(t MP_EXPORT_RENDER_WARNING_THE_VIDEO_WILL_RETAIN_ITS_PROJECT_ASPECT_RATIO)"
        fi

        # Existing output remains untouched until rendering succeeds.

        # ----------------------------------------------------
        # RENDER INFORMATION
        # ----------------------------------------------------

        echo
        echo "=================================================="
        echo "$(t MP_EXPORT_RENDER_MEDIAPANEL_EXPORT_RENDER)"
        echo "=================================================="
        echo "$(t MP_EXPORT_RENDER_PROJECT "$project")"
        echo "$(t MP_EXPORT_RENDER_TYPE "$render_type")"
        echo "$(t MP_EXPORT_RENDER_MLT_2 "$(basename "$mlt")")"
        echo "$(t MP_EXPORT_RENDER_ENCODER "$encoder_mode")"
        echo "$(t MP_EXPORT_RENDER_OUTPUT "$out")"
        echo "=================================================="
        echo

        log_project "$project" \
            "$render_type export started: $(basename "$mlt")"

        # Keep the temporary XML beside the original for other relative resources.
        # Capture failures explicitly, including when the caller uses set -e.
        
        rc=0
        (
            trap 'rm -f -- "$render_mlt" "$render_wrapper"' EXIT
            cd "$render_dir" || exit 1
            LC_ALL=C.UTF-8 \
            "${MELT_CMD[@]}" \
                -progress2 \
                "$render_input" \
                "${CONSUMER_ARGS[@]}"
        ) || rc=$?
        rm -f -- "$render_mlt" "$render_wrapper"

        if (( rc != 0 )); then
            mediapanel_log_error "$project" \
                "$(t MP_EXPORT_RENDER_EXPORT_FAILED_EXIT_CODE "$render_type" "$rc")"

            rm -f -- "$render_target"

            echo
            echo "=================================================="
            echo "$(t MP_EXPORT_RENDER_ERROR_EXPORT_RENDER_FAILED)"
            echo "=================================================="
            echo "$(t MP_EXPORT_RENDER_TYPE "$render_type")"
            echo "$(t MP_EXPORT_RENDER_ENCODER "$encoder_mode")"
            echo "$(t MP_EXPORT_RENDER_EXIT "$rc")"
            echo "=================================================="
            if [[ "$encoder_mode" == "NVENC" && "${MELT_CMD[0]}" == "flatpak" ]]; then
                echo "$(t MP_EXPORT_RENDER_INFO_IF_THE_FAILURE_MENTIONS_LIBCUDA_SO_1_NVENC)"
                export_nvenc_help
                echo "$(t MP_EXPORT_RENDER_INFO_OTHERWISE_INSPECT_THE_MLT_FILTERS_AND_ERROR_LOG)"
            fi
            echo

            return "$rc"
        fi

        if [[ ! -s "$render_target" ]]; then
            mediapanel_log_error "$project" \
                "$(t MP_EXPORT_RENDER_EXPORT_IS_MISSING_OR_EMPTY "$render_type")"

            rm -f -- "$render_target"

            echo "$(t MP_EXPORT_RENDER_ERROR_EXPORT_FILE_IS_MISSING_OR_EMPTY)"
            echo "        $out"

            return 1
        fi

        if ! mv -f -- "$render_target" "$out"; then
            rm -f -- "$render_target"
            mediapanel_log_error "$project" "$(t MP_EXPORT_RENDER_CANNOT_FINALIZE_OUTPUT "$out")"
            return 1
        fi

        ((rendered += 1))

        log_project "$project" \
            "$render_type export completed: $(basename "$out") [$encoder_mode]"

        echo
        echo "=================================================="
        echo "$(t MP_EXPORT_RENDER_OK_EXPORT_RENDERED)"
        echo "=================================================="
        echo "$(t MP_EXPORT_RENDER_TYPE "$render_type")"
        echo "$(t MP_EXPORT_RENDER_ENCODER "$encoder_mode")"
        echo "$(t MP_EXPORT_RENDER_FILE "$out")"
        echo "$(t MP_EXPORT_RENDER_SIZE "$(du -h "$out" | cut -f1)")"
        echo "=================================================="
        echo
    done

    pipeline_set "$project" "export" "done"

    log_info "$(t MP_EXPORT_RENDER_EXPORT_RENDER_COMPLETED)"
    log_info "$(t MP_EXPORT_RENDER_RENDERED_PROJECTS "$rendered")"

    echo "$(t MP_EXPORT_RENDER_OK_RENDERED_PROJECTS "$rendered")"

    return 0
}
