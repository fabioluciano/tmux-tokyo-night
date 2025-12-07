#!/usr/bin/env bash
# =============================================================================
# Plugin: nowplaying
# Description: Display currently playing media (unified media player plugin)
# 
# Automatically detects and uses the best available backend:
#   - osascript (macOS): Apple Music, Spotify via AppleScript
#   - playerctl (Linux): Any MPRIS-compatible player
#   - spotify CLI (macOS/Linux): shpotify
#   - spt (cross-platform): Spotify TUI
#
# This plugin replaces: spotify, spt, playerctl
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "nowplaying"

# Plugin-specific settings
# Format: %artist%, %track%, %album%
plugin_nowplaying_format=$(get_tmux_option "@powerkit_plugin_nowplaying_format" "$POWERKIT_PLUGIN_NOWPLAYING_FORMAT")

# Maximum length for output (0 = no limit)
plugin_nowplaying_max_length=$(get_tmux_option "@powerkit_plugin_nowplaying_max_length" "$POWERKIT_PLUGIN_NOWPLAYING_MAX_LENGTH")

# What to show when not playing (empty = hide plugin)
plugin_nowplaying_not_playing=$(get_tmux_option "@powerkit_plugin_nowplaying_not_playing" "$POWERKIT_PLUGIN_NOWPLAYING_NOT_PLAYING")

# Preferred backend: auto, osascript, playerctl, spotify, spt
plugin_nowplaying_backend=$(get_tmux_option "@powerkit_plugin_nowplaying_backend" "$POWERKIT_PLUGIN_NOWPLAYING_BACKEND")

# Ignore specific players for playerctl (comma-separated)
plugin_nowplaying_ignore_players=$(get_tmux_option "@powerkit_plugin_nowplaying_ignore_players" "$POWERKIT_PLUGIN_NOWPLAYING_IGNORE_PLAYERS")

# =============================================================================
# Backend Detection
# =============================================================================

# Cache backend detection result (avoid repeated command -v calls)
_DETECTED_BACKEND=""

# Detect best available backend
detect_backend() {
    # Return cached result if already detected
    [[ -n "$_DETECTED_BACKEND" ]] && echo "$_DETECTED_BACKEND" && return
    
    case "$plugin_nowplaying_backend" in
        spotify)
            command -v spotify &>/dev/null && _DETECTED_BACKEND="spotify" && echo "spotify" && return
            ;;
        playerctl)
            command -v playerctl &>/dev/null && _DETECTED_BACKEND="playerctl" && echo "playerctl" && return
            ;;
        spt)
            command -v spt &>/dev/null && _DETECTED_BACKEND="spt" && echo "spt" && return
            ;;
        osascript)
            is_macos && command -v osascript &>/dev/null && _DETECTED_BACKEND="osascript" && echo "osascript" && return
            ;;
        auto|*)
            # Auto-detect in order of preference
            if is_macos; then
                # macOS: osascript > shpotify > spt
                command -v osascript &>/dev/null && _DETECTED_BACKEND="osascript" && echo "osascript" && return
                command -v spotify &>/dev/null && _DETECTED_BACKEND="spotify" && echo "spotify" && return
                command -v spt &>/dev/null && _DETECTED_BACKEND="spt" && echo "spt" && return
            else
                # Linux: playerctl only (osascript not available on Linux)
                command -v playerctl &>/dev/null && _DETECTED_BACKEND="playerctl" && echo "playerctl" && return
                command -v spt &>/dev/null && _DETECTED_BACKEND="spt" && echo "spt" && return
            fi
            ;;
    esac
    
    echo ""
}

# =============================================================================
# Backend Implementations
# =============================================================================

# -----------------------------------------------------------------------------
# osascript backend (macOS)
# Supports: Spotify, Music (Apple Music), and other scriptable players
# -----------------------------------------------------------------------------
get_nowplaying_osascript() {
    local result
    
    # Single osascript call to check both Spotify and Music
    result=$(osascript -e '
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    set trackArtist to artist of current track
                    set trackName to name of current track
                    set trackAlbum to album of current track
                    return "playing|" & trackArtist & "|" & trackName & "|" & trackAlbum
                end if
            end tell
        end if
        
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    set trackArtist to artist of current track
                    set trackName to name of current track
                    set trackAlbum to album of current track
                    return "playing|" & trackArtist & "|" & trackName & "|" & trackAlbum
                end if
            end tell
        end if
        
        return ""
    ' 2>/dev/null)
    
    # Check if we got a result
    [[ "$result" != playing* ]] && return 1
    
    # Parse result (format: "playing|artist|track|album")
    local artist track album
    IFS='|' read -r _ artist track album <<< "$result"
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# playerctl backend (Linux - MPRIS)
# Supports: Any MPRIS-compatible player (Spotify, VLC, Firefox, Chrome, etc.)
# -----------------------------------------------------------------------------
get_nowplaying_playerctl() {
    local result ignore_args=""
    
    # Build ignore arguments if specified
    if [[ -n "$plugin_nowplaying_ignore_players" && "$plugin_nowplaying_ignore_players" != "IGNORE" ]]; then
        IFS=',' read -ra ignored <<< "$plugin_nowplaying_ignore_players"
        for player in "${ignored[@]}"; do
            ignore_args+=" --ignore-player=$player"
        done
    fi
    
    # Single call with format string to get all data
    # shellcheck disable=SC2086
    result=$(command playerctl $ignore_args metadata --format '{{status}}|{{artist}}|{{title}}|{{album}}' 2>/dev/null)
    
    [[ "$result" != Playing* ]] && return 1
    
    # Parse result
    local artist track album
    IFS='|' read -r _ artist track album <<< "$result"
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# spotify CLI backend (shpotify - macOS/Linux)
# Uses: https://github.com/hnarayanan/shpotify
# -----------------------------------------------------------------------------
get_nowplaying_spotify() {
    local output status artist track album
    
    # Single call to get all info (faster than 4 separate calls)
    output=$(command spotify status 2>/dev/null)
    [[ -z "$output" ]] && return 1
    
    # Strip ANSI codes from entire output at once
    output=$(printf '%s' "$output" | command sed 's/\x1b\[[0-9;]*m//g')
    
    # Check status
    status=$(printf '%s' "$output" | head -1)
    [[ "$status" != *"playing"* && "$status" != *"Playing"* ]] && return 1
    
    # Parse info (more efficient than multiple greps)
    artist=$(printf '%s' "$output" | command awk '/^Artist:/ {$1=""; print substr($0,2)}')
    track=$(printf '%s' "$output" | command awk '/^Track:/ {$1=""; print substr($0,2)}')
    album=$(printf '%s' "$output" | command awk '/^Album:/ {$1=""; print substr($0,2)}')
    
    [[ -z "$track" ]] && return 1
    
    format_output "$artist" "$track" "$album"
}

# -----------------------------------------------------------------------------
# spt backend (Spotify TUI - cross-platform)
# Uses: https://github.com/Rigellute/spotify-tui
# -----------------------------------------------------------------------------
get_nowplaying_spt() {
    local status output
    
    # Check if spt reports playing
    status=$(command spt playback --status 2>/dev/null)
    [[ -z "$status" || "$status" == *"Nothing"* ]] && return 1
    
    # spt uses its own format syntax: %a (artist), %t (track), %b (album)
    local spt_format
    spt_format=$(echo "$plugin_nowplaying_format" | command sed 's/%artist%/%a/g; s/%track%/%t/g; s/%album%/%b/g')
    
    output=$(command spt playback --format "$spt_format" 2>/dev/null)
    [[ -z "$output" ]] && return 1
    
    printf '%s' "$output"
}

# =============================================================================
# Output Formatting
# =============================================================================

# Safe string replacement that handles special characters like & correctly
# $1: haystack (string to search in)
# $2: needle (string to find)
# $3: replacement (string to replace with)
safe_replace() {
    local haystack="$1"
    local needle="$2"
    local replacement="$3"
    
    # Fast path: Use bash parameter expansion for simple replacements (no special chars)
    # This is 10x faster than sed for simple strings
    if [[ "$needle" != *[\&\\/\\\[]* ]] && [[ "$replacement" != *[\&\\/\\\[]* ]]; then
        printf '%s' "${haystack//$needle/$replacement}"
        return
    fi
    
    # Slow path: Use sed for strings with special characters
    # Escape special characters in replacement for sed
    local escaped_replacement
    escaped_replacement=$(printf '%s' "$replacement" | command sed 's/[&/\]/\\&/g')
    
    # Use sed for safe replacement
    printf '%s' "$haystack" | command sed "s|$needle|$escaped_replacement|g"
}

# Format output according to user preference
format_output() {
    local artist="$1"
    local track="$2"
    local album="$3"
    
    local output="$plugin_nowplaying_format"
    
    # Use safe_replace to avoid issues with special characters like &
    output=$(safe_replace "$output" "%artist%" "$artist")
    output=$(safe_replace "$output" "%track%" "$track")
    output=$(safe_replace "$output" "%album%" "$album")
    
    # Truncate if max_length is set
    if [[ "$plugin_nowplaying_max_length" -gt 0 && ${#output} -gt $plugin_nowplaying_max_length ]]; then
        output="${output:0:$((plugin_nowplaying_max_length - 1))}…"
    fi
    
    printf '%s' "$output"
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Hide if content is empty or matches "not playing" message
    if [[ -z "$content" || "$content" == "$plugin_nowplaying_not_playing" ]]; then
        show="0"
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Detect backend
    local backend
    backend=$(detect_backend)
    
    # No backend available
    [[ -z "$backend" ]] && return 0
    
    # Try cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        # Return cached value (even if empty)
        printf '%s' "$cached_value"
        return 0
    fi
    
    # Fetch from appropriate backend
    local result=""
    case "$backend" in
        spotify)
            result=$(get_nowplaying_spotify) || result=""
            ;;
        playerctl)
            result=$(get_nowplaying_playerctl) || result=""
            ;;
        spt)
            result=$(get_nowplaying_spt) || result=""
            ;;
        osascript)
            result=$(get_nowplaying_osascript) || result=""
            ;;
    esac
    
    # Use "not playing" message if no result
    if [[ -z "$result" ]]; then
        result="$plugin_nowplaying_not_playing"
    fi
    
    # Cache and output
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
