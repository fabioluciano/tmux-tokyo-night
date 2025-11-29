#!/usr/bin/env bash
# =============================================================================
# Plugin: spotify
# Description: Display currently playing Spotify track (cross-platform)
# 
# Supported backends (in order of preference):
#   - osascript (macOS): Single AppleScript call (FAST!)
#   - playerctl (Linux): MPRIS-compatible media player control
#   - shpotify (macOS): https://github.com/hnarayanan/shpotify
#   - spt (cross-platform): https://github.com/Rigellute/spotify-tui
#
# PERFORMANCE: Optimized to use single command per backend.
# osascript now fetches all data in one call instead of 4 separate calls.
#
# Dependencies: At least one of the above backends
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_spotify_icon=$(get_tmux_option "@theme_plugin_spotify_icon" "$PLUGIN_SPOTIFY_ICON")
# shellcheck disable=SC2034
plugin_spotify_accent_color=$(get_tmux_option "@theme_plugin_spotify_accent_color" "$PLUGIN_SPOTIFY_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_spotify_accent_color_icon=$(get_tmux_option "@theme_plugin_spotify_accent_color_icon" "$PLUGIN_SPOTIFY_ACCENT_COLOR_ICON")

# Format: %artist%, %track%, %album%
plugin_spotify_format=$(get_tmux_option "@theme_plugin_spotify_format" "$PLUGIN_SPOTIFY_FORMAT")

# Maximum length for output (0 = no limit)
plugin_spotify_max_length=$(get_tmux_option "@theme_plugin_spotify_max_length" "$PLUGIN_SPOTIFY_MAX_LENGTH")

# What to show when not playing
plugin_spotify_not_playing=$(get_tmux_option "@theme_plugin_spotify_not_playing" "$PLUGIN_SPOTIFY_NOT_PLAYING")

# Preferred backend: auto, shpotify, playerctl, spt, osascript
plugin_spotify_backend=$(get_tmux_option "@theme_plugin_spotify_backend" "$PLUGIN_SPOTIFY_BACKEND")

# Cache TTL in seconds (default: 5 seconds - music changes frequently)
SPOTIFY_CACHE_TTL=$(get_tmux_option "@theme_plugin_spotify_cache_ttl" "$PLUGIN_SPOTIFY_CACHE_TTL")
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
            # Auto-detect in order of preference (osascript first for macOS - fastest!)
            if is_macos; then
                # macOS: prefer osascript (single call) > shpotify > spt
                command_exists "osascript" && echo "osascript" && return
                command_exists "spotify" && echo "shpotify" && return
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
# osascript backend (macOS - OPTIMIZED: single AppleScript call)
# Fetches state, artist, track, album in ONE call
# -----------------------------------------------------------------------------
get_spotify_osascript() {
    local result
    
    # Single AppleScript call that returns all data at once
    # Format: "state|artist|track|album"
    result=$(osascript -e '
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    set trackArtist to artist of current track
                    set trackName to name of current track
                    set trackAlbum to album of current track
                    return "playing|" & trackArtist & "|" & trackName & "|" & trackAlbum
                else
                    return "paused"
                end if
            end tell
        else
            return "closed"
        end if
    ' 2>/dev/null)
    
    # Check state
    [[ "$result" != playing* ]] && return 1
    
    # Parse result (format: "playing|artist|track|album")
    local artist track album
    IFS='|' read -r _ artist track album <<< "$result"
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# playerctl backend (Linux - MPRIS) - OPTIMIZED: single call
# Uses: playerctl metadata --format
# -----------------------------------------------------------------------------
get_spotify_playerctl() {
    local result
    
    # Single call with format string to get all data
    result=$(playerctl -p spotify metadata --format '{{status}}|{{artist}}|{{title}}|{{album}}' 2>/dev/null)
    
    [[ "$result" != Playing* ]] && return 1
    
    # Parse result
    local artist track album
    IFS='|' read -r _ artist track album <<< "$result"
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# shpotify backend (macOS) - Multiple calls but cached
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
