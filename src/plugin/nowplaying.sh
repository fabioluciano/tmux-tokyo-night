#!/usr/bin/env bash
# Plugin: nowplaying - Display currently playing media
# Backends: osascript (macOS), playerctl (Linux), spotify CLI, spt

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT_DIR/../plugin_bootstrap.sh"

plugin_init "nowplaying"

# Configuration
_format=$(get_tmux_option "@powerkit_plugin_nowplaying_format" "$POWERKIT_PLUGIN_NOWPLAYING_FORMAT")
_max_len=$(get_tmux_option "@powerkit_plugin_nowplaying_max_length" "$POWERKIT_PLUGIN_NOWPLAYING_MAX_LENGTH")
_not_playing=$(get_tmux_option "@powerkit_plugin_nowplaying_not_playing" "$POWERKIT_PLUGIN_NOWPLAYING_NOT_PLAYING")
_backend=$(get_tmux_option "@powerkit_plugin_nowplaying_backend" "$POWERKIT_PLUGIN_NOWPLAYING_BACKEND")
_ignore=$(get_tmux_option "@powerkit_plugin_nowplaying_ignore_players" "$POWERKIT_PLUGIN_NOWPLAYING_IGNORE_PLAYERS")

# Escape special characters for bash string replacement
# The & character in replacement string means "matched pattern"
escape_replacement() {
    local str="$1"
    str="${str//\\/\\\\}"  # Escape backslashes first
    str="${str//&/\\&}"    # Escape ampersands
    printf '%s' "$str"
}

# Format output with artist/track/album
format_output() {
    local artist="$1" track="$2" album="$3"
    # Escape special chars to prevent bash substitution issues
    local safe_artist safe_track safe_album
    safe_artist=$(escape_replacement "$artist")
    safe_track=$(escape_replacement "$track")
    safe_album=$(escape_replacement "$album")
    
    local out="${_format//%artist%/$safe_artist}"
    out="${out//%track%/$safe_track}"
    out="${out//%album%/$safe_album}"
    [[ "$_max_len" -gt 0 && ${#out} -gt $_max_len ]] && out="${out:0:$((_max_len - 1))}…"
    printf '%s' "$out"
}

# osascript backend (macOS - Spotify/Music)
get_osascript() {
    local r
    r=$(osascript -e '
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    return "playing|" & artist of current track & "|" & name of current track & "|" & album of current track
                end if
            end tell
        end if
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    return "playing|" & artist of current track & "|" & name of current track & "|" & album of current track
                end if
            end tell
        end if
        return ""
    ' 2>/dev/null)
    [[ "$r" != playing* ]] && return 1
    local a t b; IFS='|' read -r _ a t b <<< "$r"
    [[ -z "$t" ]] && return 1
    format_output "$a" "$t" "$b"
}

# playerctl backend (Linux MPRIS)
get_playerctl() {
    local ignore_args=""
    if [[ -n "$_ignore" && "$_ignore" != "IGNORE" ]]; then
        IFS=',' read -ra players <<< "$_ignore"
        for p in "${players[@]}"; do ignore_args+=" --ignore-player=$p"; done
    fi
    # shellcheck disable=SC2086
    local r=$(command playerctl $ignore_args metadata --format '{{status}}|{{artist}}|{{title}}|{{album}}' 2>/dev/null)
    [[ "$r" != Playing* ]] && return 1
    local a t b; IFS='|' read -r _ a t b <<< "$r"
    [[ -z "$t" ]] && return 1
    format_output "$a" "$t" "$b"
}

# shpotify CLI backend
get_spotify_cli() {
    local out=$(command spotify status 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    [[ -z "$out" ]] && return 1
    [[ "$(head -1 <<< "$out")" != *[Pp]laying* ]] && return 1
    local a=$(awk '/^Artist:/ {$1=""; print substr($0,2)}' <<< "$out")
    local t=$(awk '/^Track:/ {$1=""; print substr($0,2)}' <<< "$out")
    local b=$(awk '/^Album:/ {$1=""; print substr($0,2)}' <<< "$out")
    [[ -z "$t" ]] && return 1
    format_output "$a" "$t" "$b"
}

# spt (Spotify TUI) backend
get_spt() {
    local status=$(command spt playback --status 2>/dev/null)
    [[ -z "$status" || "$status" == *"Nothing"* ]] && return 1
    local fmt="${_format//%artist%/%a}"; fmt="${fmt//%track%/%t}"; fmt="${fmt//%album%/%b}"
    command spt playback --format "$fmt" 2>/dev/null
}

# Detect best backend
detect_backend() {
    case "$_backend" in
        spotify)   command -v spotify &>/dev/null && echo "spotify" && return ;;
        playerctl) command -v playerctl &>/dev/null && echo "playerctl" && return ;;
        spt)       command -v spt &>/dev/null && echo "spt" && return ;;
        osascript) is_macos && echo "osascript" && return ;;
        auto|*)
            if is_macos; then
                echo "osascript" && return
            else
                command -v playerctl &>/dev/null && echo "playerctl" && return
                command -v spt &>/dev/null && echo "spt" && return
            fi
            ;;
    esac
}

plugin_get_type() { printf 'conditional'; }

plugin_get_display_info() {
    local content="$1"
    [[ -z "$content" || "$content" == "$_not_playing" ]] && echo "0:::" || echo "1:::"
}

load_plugin() {
    local backend=$(detect_backend)
    [[ -z "$backend" ]] && return 0

    local cached
    if cached=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached"
        return 0
    fi

    local result=""
    case "$backend" in
        osascript)  result=$(get_osascript) ;;
        playerctl)  result=$(get_playerctl) ;;
        spotify)    result=$(get_spotify_cli) ;;
        spt)        result=$(get_spt) ;;
    esac

    [[ -z "$result" ]] && result="$_not_playing"
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && load_plugin || true
