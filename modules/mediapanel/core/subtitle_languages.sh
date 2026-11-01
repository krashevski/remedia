#!/usr/bin/env bash
# Shared subtitle preferences. Bash >= 4.3. Loads local i18n; no network calls.
# Language codes follow whisper.cpp's g_lang table (large-v3).
# https://github.com/ggml-org/whisper.cpp/blob/master/src/whisper.cpp

declare -gA MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES=(
    [en]=MP_LANG_EN [zh]=MP_LANG_ZH [de]=MP_LANG_DE [es]=MP_LANG_ES [ru]=MP_LANG_RU
    [ko]=MP_LANG_KO [fr]=MP_LANG_FR [ja]=MP_LANG_JA [pt]=MP_LANG_PT [tr]=MP_LANG_TR
    [pl]=MP_LANG_PL [ca]=MP_LANG_CA [nl]=MP_LANG_NL [ar]=MP_LANG_AR [sv]=MP_LANG_SV
    [it]=MP_LANG_IT [id]=MP_LANG_ID [hi]=MP_LANG_HI [fi]=MP_LANG_FI [vi]=MP_LANG_VI
    [he]=MP_LANG_HE [uk]=MP_LANG_UK [el]=MP_LANG_EL [ms]=MP_LANG_MS [cs]=MP_LANG_CS
    [ro]=MP_LANG_RO [da]=MP_LANG_DA [hu]=MP_LANG_HU [ta]=MP_LANG_TA [no]=MP_LANG_NO
    [th]=MP_LANG_TH [ur]=MP_LANG_UR [hr]=MP_LANG_HR [bg]=MP_LANG_BG [lt]=MP_LANG_LT
    [la]=MP_LANG_LA [mi]=MP_LANG_MI [ml]=MP_LANG_ML [cy]=MP_LANG_CY [sk]=MP_LANG_SK
    [te]=MP_LANG_TE [fa]=MP_LANG_FA [lv]=MP_LANG_LV [bn]=MP_LANG_BN [sr]=MP_LANG_SR
    [az]=MP_LANG_AZ [sl]=MP_LANG_SL [kn]=MP_LANG_KN [et]=MP_LANG_ET [mk]=MP_LANG_MK
    [br]=MP_LANG_BR [eu]=MP_LANG_EU [is]=MP_LANG_IS [hy]=MP_LANG_HY [ne]=MP_LANG_NE
    [mn]=MP_LANG_MN [bs]=MP_LANG_BS [kk]=MP_LANG_KK [sq]=MP_LANG_SQ [sw]=MP_LANG_SW
    [gl]=MP_LANG_GL [mr]=MP_LANG_MR [pa]=MP_LANG_PA [si]=MP_LANG_SI [km]=MP_LANG_KM
    [sn]=MP_LANG_SN [yo]=MP_LANG_YO [so]=MP_LANG_SO [af]=MP_LANG_AF [oc]=MP_LANG_OC
    [ka]=MP_LANG_KA [be]=MP_LANG_BE [tg]=MP_LANG_TG [sd]=MP_LANG_SD [gu]=MP_LANG_GU
    [am]=MP_LANG_AM [yi]=MP_LANG_YI [lo]=MP_LANG_LO [uz]=MP_LANG_UZ [fo]=MP_LANG_FO
    [ht]=MP_LANG_HT [ps]=MP_LANG_PS [tk]=MP_LANG_TK [nn]=MP_LANG_NN [mt]=MP_LANG_MT
    [sa]=MP_LANG_SA [lb]=MP_LANG_LB [my]=MP_LANG_MY [bo]=MP_LANG_BO [tl]=MP_LANG_TL
    [mg]=MP_LANG_MG [as]=MP_LANG_AS [tt]=MP_LANG_TT [haw]=MP_LANG_HAW [ln]=MP_LANG_LN
    [ha]=MP_LANG_HA [ba]=MP_LANG_BA [jw]=MP_LANG_JW [su]=MP_LANG_SU [yue]=MP_LANG_YUE
)

mediapanel_subtitle_language_valid() {
    local code="${1:-}"
    [[ "$code" =~ ^[a-z]{2,3}$ ]] || return 1
    [[ -n "${MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[$code]:-}" ]]
}

mediapanel_subtitle_language_name() {
    local code="${1:-}"
    if [[ "$code" == auto ]]; then
        t MP_SUB_AUTO
    elif mediapanel_subtitle_language_valid "$code"; then
        t "${MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[$code]}"
    else
        return 1
    fi
}

mediapanel_subtitle_languages_validate() {
    if (( $# < 1 || $# > 4 )); then
        t MP_SUB_ERROR_COUNT >&2
        return 1
    fi
    local code
    local -A seen=()
    for code in "$@"; do
        if ! mediapanel_subtitle_language_valid "$code"; then
            t MP_SUB_ERROR_CODE "$code" >&2
            return 1
        fi
        if [[ -n "${seen[$code]:-}" ]]; then
            t MP_SUB_ERROR_DUPLICATE "$code" >&2
            return 1
        fi
        seen[$code]=1
    done
}

mediapanel_subtitle_languages_file() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    # XDG_CONFIG_HOME must be absolute; ignore relative values.
    [[ "$config_home" == /* ]] || config_home="$HOME/.config"
    printf '%s/remedia/mediapanel/subtitle-languages.conf\n' "${config_home%/}"
}

mediapanel_subtitle_languages_load() {
    declare -ga MEDIAPANEL_SUBTITLE_LANGUAGES=(ru kk en)
    local file line
    file="$(mediapanel_subtitle_languages_file)" || return 1
    [[ -e "$file" || -L "$file" ]] || return 0
    if [[ ! -f "$file" || ! -r "$file" ]]; then
        t MP_SUB_WARN_READ "$file" >&2
        return 0
    fi
    # Preferences are DATA, never source/eval them as shell code.
    local -a loaded=() words=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        read -r -a words <<< "$line"
        loaded+=("${words[@]}")
        # Stop early even for a damaged/oversized file.
        (( ${#loaded[@]} <= 4 )) || break
    done < "$file"
    if mediapanel_subtitle_languages_validate "${loaded[@]}"; then
        MEDIAPANEL_SUBTITLE_LANGUAGES=("${loaded[@]}")
    else
        t MP_SUB_WARN_INVALID "$file" >&2
    fi
}

mediapanel_subtitle_languages_save() (
    # Subshell keeps umask changes local to this write.
    mediapanel_subtitle_languages_validate "$@" || return 1
    umask 077
    local file directory temporary
    file="$(mediapanel_subtitle_languages_file)" || return 1
    directory="${file%/*}"
    mkdir -p -- "$directory" || return 1
    temporary="$(mktemp "$directory/.subtitle-languages.XXXXXX")" || return 1
    if ! printf '%s\n' "$*" > "$temporary" || ! mv -fT -- "$temporary" "$file"; then
        rm -f -- "$temporary"
        t MP_SUB_ERROR_SAVE >&2
        return 1
    fi
)

mediapanel_subtitle_languages_status() {
    mediapanel_subtitle_languages_load || return 1
    local code separator=''
    printf '%s' "$(t MP_SUB_LANGUAGES_LABEL)"
    for code in "${MEDIAPANEL_SUBTITLE_LANGUAGES[@]}"; do
        printf '%s%s (%s)' "$separator" "$(mediapanel_subtitle_language_name "$code")" "$code"
        separator=', '
    done
    printf '\n'
}

# Sets MEDIAPANEL_SUBTITLE_LANGUAGE; return 2 means a deliberate cancellation.
# Keep stdout for UI, not command substitution, so prompts stay visible.
mediapanel_subtitle_language_select() {
    MEDIAPANEL_SUBTITLE_LANGUAGE=''
    local language="${CLI_LANGUAGE:-${SUBTITLE_LANGUAGE:-}}"
    local choice index
    mediapanel_subtitle_languages_load || return 1
    if [[ -z "$language" ]]; then
        if [[ "${CLI_NO_UI:-0}" == 1 ]]; then
            language="${MEDIAPANEL_SUBTITLE_LANGUAGES[0]}"
        else
            echo
            t MP_SUB_SELECT
            for index in "${!MEDIAPANEL_SUBTITLE_LANGUAGES[@]}"; do
                language="${MEDIAPANEL_SUBTITLE_LANGUAGES[$index]}"
                printf ' %d) %s (%s)\n' "$((index + 1))" "$(mediapanel_subtitle_language_name "$language")" "$language"
            done
            local auto_choice=$(( ${#MEDIAPANEL_SUBTITLE_LANGUAGES[@]} + 1 ))
            printf ' %d) %s\n\n %s\n\n' "$auto_choice" "$(t MP_SUB_AUTO)" "$(t MP_SUB_CANCEL_OPTION)"
            read -r -p "$(t MP_SUB_PROMPT "$auto_choice")" choice || {
                t MP_SUB_ERROR_READ >&2
                return 1
            }
            [[ -n "$choice" ]] || choice=1
            if [[ "$choice" == 0 ]]; then
                t MP_SUB_CANCELLED
                return 2
            fi
            # At most five options; reject arbitrary arithmetic input.
            if [[ ! "$choice" =~ ^[1-5]$ ]] || (( choice > auto_choice )); then
                t MP_SUB_ERROR_SELECTION >&2
                return 1
            fi
            if (( choice == auto_choice )); then
                language=auto
            else
                language="${MEDIAPANEL_SUBTITLE_LANGUAGES[$((choice - 1))]}"
            fi
        fi
    fi
    language="${language,,}"
    if [[ "$language" != auto ]] && ! mediapanel_subtitle_language_valid "$language"; then
        t MP_SUB_ERROR_CODE "$language" >&2
        return 1
    fi
    MEDIAPANEL_SUBTITLE_LANGUAGE="$language"
}
