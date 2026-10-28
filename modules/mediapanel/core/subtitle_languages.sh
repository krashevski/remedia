#!/usr/bin/env bash
# Shared subtitle preferences. Bash >= 4.3. No work or network calls on source.
# Language codes follow whisper.cpp's g_lang table (large-v3).
# https://github.com/ggml-org/whisper.cpp/blob/master/src/whisper.cpp

declare -gA MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES=(
    [en]=English [zh]=Chinese [de]=German [es]=Spanish [ru]=Russian
    [ko]=Korean [fr]=French [ja]=Japanese [pt]=Portuguese [tr]=Turkish
    [pl]=Polish [ca]=Catalan [nl]=Dutch [ar]=Arabic [sv]=Swedish
    [it]=Italian [id]=Indonesian [hi]=Hindi [fi]=Finnish [vi]=Vietnamese
    [he]=Hebrew [uk]=Ukrainian [el]=Greek [ms]=Malay [cs]=Czech
    [ro]=Romanian [da]=Danish [hu]=Hungarian [ta]=Tamil [no]=Norwegian
    [th]=Thai [ur]=Urdu [hr]=Croatian [bg]=Bulgarian [lt]=Lithuanian
    [la]=Latin [mi]=Maori [ml]=Malayalam [cy]=Welsh [sk]=Slovak
    [te]=Telugu [fa]=Persian [lv]=Latvian [bn]=Bengali [sr]=Serbian
    [az]=Azerbaijani [sl]=Slovenian [kn]=Kannada [et]=Estonian [mk]=Macedonian
    [br]=Breton [eu]=Basque [is]=Icelandic [hy]=Armenian [ne]=Nepali
    [mn]=Mongolian [bs]=Bosnian [kk]=Kazakh [sq]=Albanian [sw]=Swahili
    [gl]=Galician [mr]=Marathi [pa]=Punjabi [si]=Sinhala [km]=Khmer
    [sn]=Shona [yo]=Yoruba [so]=Somali [af]=Afrikaans [oc]=Occitan
    [ka]=Georgian [be]=Belarusian [tg]=Tajik [sd]=Sindhi [gu]=Gujarati
    [am]=Amharic [yi]=Yiddish [lo]=Lao [uz]=Uzbek [fo]=Faroese
    [ht]="Haitian Creole" [ps]=Pashto [tk]=Turkmen [nn]=Nynorsk [mt]=Maltese
    [sa]=Sanskrit [lb]=Luxembourgish [my]=Myanmar [bo]=Tibetan [tl]=Tagalog
    [mg]=Malagasy [as]=Assamese [tt]=Tatar [haw]=Hawaiian [ln]=Lingala
    [ha]=Hausa [ba]=Bashkir [jw]=Javanese [su]=Sundanese [yue]=Cantonese
)

mediapanel_subtitle_language_valid() {
    local code="${1:-}"
    [[ "$code" =~ ^[a-z]{2,3}$ ]] || return 1
    [[ -n "${MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[$code]:-}" ]]
}

mediapanel_subtitle_language_name() {
    local code="${1:-}"
    if [[ "$code" == auto ]]; then
        printf '%s\n' 'Auto detect'
    elif mediapanel_subtitle_language_valid "$code"; then
        printf '%s\n' "${MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[$code]}"
    else
        return 1
    fi
}

mediapanel_subtitle_languages_validate() {
    if (( $# < 1 || $# > 4 )); then
        echo '[ERROR] Select between 1 and 4 languages.' >&2
        return 1
    fi
    local code
    local -A seen=()
    for code in "$@"; do
        if ! mediapanel_subtitle_language_valid "$code"; then
            printf '[ERROR] Unsupported Whisper language code: %s\n' "$code" >&2
            return 1
        fi
        if [[ -n "${seen[$code]:-}" ]]; then
            printf '[ERROR] Duplicate language code: %s\n' "$code" >&2
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
        printf '[WARN] Cannot read subtitle language settings; using ru kk en: %s\n' "$file" >&2
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
        printf '[WARN] Invalid subtitle language settings; using ru kk en: %s\n' "$file" >&2
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
        echo '[ERROR] Cannot save subtitle language settings.' >&2
        return 1
    fi
)

mediapanel_subtitle_languages_status() {
    mediapanel_subtitle_languages_load || return 1
    local code separator=''
    printf '   Subtitle languages: '
    for code in "${MEDIAPANEL_SUBTITLE_LANGUAGES[@]}"; do
        printf '%s%s (%s)' "$separator" "${MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[$code]}" "$code"
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
            echo 'Select subtitle language (spoken audio language):'
            for index in "${!MEDIAPANEL_SUBTITLE_LANGUAGES[@]}"; do
                language="${MEDIAPANEL_SUBTITLE_LANGUAGES[$index]}"
                printf ' %d) %s (%s)\n' "$((index + 1))" "${MEDIAPANEL_SUBTITLE_LANGUAGE_NAMES[$language]}" "$language"
            done
            local auto_choice=$(( ${#MEDIAPANEL_SUBTITLE_LANGUAGES[@]} + 1 ))
            printf ' %d) Auto detect\n\n 0) Cancel\n\n' "$auto_choice"
            read -r -p "Choice [1-$auto_choice, default 1]> " choice || {
                echo '[ERROR] Cannot read language selection' >&2
                return 1
            }
            [[ -n "$choice" ]] || choice=1
            if [[ "$choice" == 0 ]]; then
                echo '[INFO] Subtitle generation cancelled'
                return 2
            fi
            # At most five options; reject arbitrary arithmetic input.
            if [[ ! "$choice" =~ ^[1-5]$ ]] || (( choice > auto_choice )); then
                echo '[ERROR] Invalid language selection' >&2
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
        printf '[ERROR] Unsupported Whisper language code: %s\n' "$language" >&2
        return 1
    fi
    MEDIAPANEL_SUBTITLE_LANGUAGE="$language"
}
