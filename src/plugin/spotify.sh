#!/usr/bin/env bash
# =============================================================================
# Plugin: spotify
# Description: Display currently playing Spotify track (cross-platform)
# 
# Supported backends (in order of preference):
#   - shpotify (macOS): https://github.com/hnarayanan/shpotify
#   - playerctl (Linux): MPRIS-compatible media player control
#   - spt (cross-platform): https://github.com/Rigellute/spotify-tui
#   - osascript (macOS fallback): Direct AppleScript to Spotify.app
#
# Dependencies: At least one of the above backends
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_spotify_icon=$(get_tmux_option "@theme_plugin_spotify_icon" "󰝚 ")
# shellcheck disable=SC2034
plugin_spotify_accent_color=$(get_tmux_option "@theme_plugin_spotify_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_spotify_accent_color_icon=$(get_tmux_option "@theme_plugin_spotify_accent_color_icon" "blue0")

# Format: %artist%, %track%, %album%
plugin_spotify_format=$(get_tmux_option "@theme_plugin_spotify_format" "%artist% - %track%")

# Maximum length for output (0 = no limit)
plugin_spotify_max_length=$(get_tmux_option "@theme_plugin_spotify_max_length" "40")

# What to show when not playing
plugin_spotify_not_playing=$(get_tmux_option "@theme_plugin_spotify_not_playing" "")

# Preferred backend: auto, shpotify, playerctl, spt, osascript
plugin_spotify_backend=$(get_tmux_option "@theme_plugin_spotify_backend" "auto")

# Cache TTL in seconds (default: 5 seconds - music changes frequently)
SPOTIFY_CACHE_TTL=$(get_tmux_option "@theme_plugin_spotify_cache_ttl" "5")
SPOTIFY_CACHE_KEY="spotify"

export plugin_spotify_icon plugin_spotify_accent_color plugin_spotify_accent_color_icon

# =============================================================================
# Backend Detection
# =============================================================================

command_exists() {
    command -v "$1" &>/dev/null
}

# Detect best available backend
detect_backend() {
    case "$plugin_spotify_backend" in
        shpotify)
            command_exists "spotify" && echo "shpotify" && return
            ;;
        playerctl)
            command_exists "playerctl" && echo "playerctl" && return
            ;;
        spt)
            command_exists "spt" && echo "spt" && return
            ;;
        osascript)
            command_exists "osascript" && echo "osascript" && return
            ;;
        auto|*)
            # Auto-detect in order of preference
            if is_macos; then
                # macOS: prefer shpotify > osascript > spt
                command_exists "spotify" && echo "shpotify" && return
                command_exists "osascript" && echo "osascript" && return
                command_exists "spt" && echo "spt" && return
            else
                # Linux: prefer playerctl > spt
                command_exists "playerctl" && echo "playerctl" && return
                command_exists "spt" && echo "spt" && return
            fi
            ;;
    esac
    
    echo ""
}

# =============================================================================
# Backend Implementations
# =============================================================================

# -----------------------------------------------------------------------------
# shpotify backend (macOS)
# Uses: spotify status track/artist/album
# -----------------------------------------------------------------------------
get_spotify_shpotify() {
    local status artist track album
    
    # Check if Spotify is running and playing
    # Strip ANSI color codes from output
    status=$(spotify status 2>/dev/null | head -1 | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$status" != *"playing"* && "$status" != *"Playing"* ]] && return 1
    
    # Get track info (strip "Artist: ", "Track: ", "Album: " prefixes and ANSI codes)
    artist=$(spotify status artist 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g; s/^Artist: //')
    track=$(spotify status track 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g; s/^Track: //')
    album=$(spotify status album 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g; s/^Album: //')
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# playerctl backend (Linux - MPRIS)
# Uses: playerctl metadata
# -----------------------------------------------------------------------------
get_spotify_playerctl() {
    local status artist track album
    
    # Check if Spotify is playing via playerctl
    status=$(playerctl -p spotify status 2>/dev/null)
    [[ "$status" != "Playing" ]] && return 1
    
    artist=$(playerctl -p spotify metadata artist 2>/dev/null)
    track=$(playerctl -p spotify metadata title 2>/dev/null)
    album=$(playerctl -p spotify metadata album 2>/dev/null)
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# spt backend (cross-platform via Spotify API)
# Uses: spt playback --format
# -----------------------------------------------------------------------------
get_spotify_spt() {
    local status output
    
    # Check if spt reports playing
    status=$(spt playback --status 2>/dev/null)
    [[ -z "$status" || "$status" == *"Nothing"* ]] && return 1
    
    # spt uses its own format syntax
    local spt_format
    spt_format=$(echo "$plugin_spotify_format" | sed 's/%artist%/%a/g; s/%track%/%t/g; s/%album%/%b/g')
    
    output=$(spt playback --format "$spt_format" 2>/dev/null)
    [[ -z "$output" ]] && return 1
    
    printf '%s' "$output"
}

# -----------------------------------------------------------------------------
# osascript backend (macOS - direct AppleScript)
# Fallback for macOS without shpotify installed
# -----------------------------------------------------------------------------
get_spotify_osascript() {
    local state artist track album
    
    # Check if Spotify is running
    if ! osascript -e 'application "Spotify" is running' 2>/dev/null | grep -q "true"; then
        return 1
    fi
    
    # Check player state
    state=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null)
    [[ "$state" != "playing" ]] && return 1
    
    artist=$(osascript -e 'tell application "Spotify" to artist of current track as string' 2>/dev/null)
    track=$(osascript -e 'tell application "Spotify" to name of current track as string' 2>/dev/null)
    album=$(osascript -e 'tell application "Spotify" to album of current track as string' 2>/dev/null)
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# =============================================================================
# Output Formatting
# =============================================================================

# Format output according to user preference
format_output() {
    local artist="$1"
    local track="$2"
    local album="$3"
    
    local output="$plugin_spotify_format"
    output="${output//%artist%/$artist}"
    output="${output//%track%/$track}"
    output="${output//%album%/$album}"
    
    # Truncate if max_length is set
    if [[ "$plugin_spotify_max_length" -gt 0 && ${#output} -gt $plugin_spotify_max_length ]]; then
        output="${output:0:$((plugin_spotify_max_length - 1))}…"
    fi
    
    printf '%s' "$output"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Detect backend
    local backend
    backend=$(detect_backend)
    
    # No backend available - fail silently
    [[ -z "$backend" ]] && return 0
    
    # Try cache first
    local cached_value
    if cached_value=$(cache_get "$SPOTIFY_CACHE_KEY" "$SPOTIFY_CACHE_TTL"); then
        # Don't return cached empty/"not playing" values
        if [[ -n "$cached_value" && "$cached_value" != "$plugin_spotify_not_playing" ]]; then
            printf '%s' "$cached_value"
            return 0
        fi
    fi
    
    # Fetch from appropriate backend
    local result
    case "$backend" in
        shpotify)
            result=$(get_spotify_shpotify)
            ;;
        playerctl)
            result=$(get_spotify_playerctl)
            ;;
        spt)
            result=$(get_spotify_spt)
            ;;
        osascript)
            result=$(get_spotify_osascript)
            ;;
    esac
    
    # Handle not playing / no result
    if [[ -z "$result" ]]; then
        result="$plugin_spotify_not_playing"
    fi
    
    # Cache and output
    cache_set "$SPOTIFY_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
