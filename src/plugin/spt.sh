#!/usr/bin/env bash
# =============================================================================
# Plugin: spt (Spotify TUI)
# Description: Display currently playing track from Spotify via spt
# Dependencies: spt (Spotify TUI - https://github.com/Rigellute/spotify-tui)
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
plugin_spt_icon=$(get_tmux_option "@theme_plugin_spt_icon" "󰝚 ")
# shellcheck disable=SC2034
plugin_spt_accent_color=$(get_tmux_option "@theme_plugin_spt_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_spt_accent_color_icon=$(get_tmux_option "@theme_plugin_spt_accent_color_icon" "blue0")

# Plugin-specific options
plugin_spt_format=$(get_tmux_option "@theme_plugin_spt_format" "%a - %t")

# Cache TTL in seconds (default: 5 seconds - music changes frequently)
SPT_CACHE_TTL=$(get_tmux_option "@theme_plugin_spt_cache_ttl" "5")
SPT_CACHE_KEY="spt"

export plugin_spt_icon plugin_spt_accent_color plugin_spt_accent_color_icon

# =============================================================================
# Helper Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Check if spt is available
# Returns: 0 if available, 1 otherwise
# -----------------------------------------------------------------------------
spt_is_available() {
    command -v spt &>/dev/null
}

# -----------------------------------------------------------------------------
# Check if Spotify is currently playing
# Returns: 0 if playing, 1 otherwise
# -----------------------------------------------------------------------------
spt_is_playing() {
    spt playback --status &>/dev/null
}

# -----------------------------------------------------------------------------
# Get current track information
# Returns: Formatted track info string
# -----------------------------------------------------------------------------
spt_get_track_info() {
    spt playback --format "$plugin_spt_format" 2>/dev/null
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check dependency - fail silently if spt is not available
    if ! spt_is_available; then
        return 0
    fi

    # Try to get from cache first
    local cached_value
    if cached_value=$(cache_get "$SPT_CACHE_KEY" "$SPT_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    # Fetch fresh data
    local result
    if spt_is_playing; then
        result=$(spt_get_track_info)
    else
        result="Not Playing"
    fi

    # Update cache and output result
    cache_set "$SPT_CACHE_KEY" "$result"
    printf '%s' "$result"
}

load_plugin
