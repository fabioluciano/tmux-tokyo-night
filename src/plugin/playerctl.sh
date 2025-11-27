#!/usr/bin/env bash
# =============================================================================
# Plugin: playerctl
# Description: Display currently playing media information via MPRIS
# Dependencies: playerctl
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
plugin_playerctl_icon=$(get_tmux_option "@theme_plugin_playerctl_icon" "󰝚 ")
# shellcheck disable=SC2034
plugin_playerctl_accent_color=$(get_tmux_option "@theme_plugin_playerctl_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_playerctl_accent_color_icon=$(get_tmux_option "@theme_plugin_playerctl_accent_color_icon" "blue0")

# Plugin-specific options
plugin_playerctl_format=$(get_tmux_option "@theme_plugin_playerctl_format" "{{artist}} - {{title}}")
plugin_playerctl_ignore_players=$(get_tmux_option "@theme_plugin_playerctl_ignore_players" "IGNORE")

# Cache TTL in seconds (default: 5 seconds - media changes frequently)
PLAYERCTL_CACHE_TTL=$(get_tmux_option "@theme_plugin_playerctl_cache_ttl" "5")
PLAYERCTL_CACHE_KEY="playerctl"

export plugin_playerctl_icon plugin_playerctl_accent_color plugin_playerctl_accent_color_icon

# =============================================================================
# Helper Functions
# =============================================================================

# -----------------------------------------------------------------------------
# Check if playerctl is available
# Returns: 0 if available, 1 otherwise
# -----------------------------------------------------------------------------
playerctl_is_available() {
    command -v playerctl &>/dev/null
}

# -----------------------------------------------------------------------------
# Check if any media is currently playing
# Returns: 0 if playing, 1 otherwise
# -----------------------------------------------------------------------------
playerctl_is_playing() {
    local status
    status=$(playerctl status -i "$plugin_playerctl_ignore_players" 2>/dev/null)
    [[ "$status" == "Playing" ]]
}

# -----------------------------------------------------------------------------
# Get current track information
# Returns: Formatted track info string
# -----------------------------------------------------------------------------
playerctl_get_track_info() {
    playerctl metadata -i "$plugin_playerctl_ignore_players" \
        --format "$plugin_playerctl_format" 2>/dev/null
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check dependency - return empty if not available
    if ! playerctl_is_available; then
        return 0
    fi

    # Try to get from cache first
    local cached_value
    if cached_value=$(cache_get "$PLAYERCTL_CACHE_KEY" "$PLAYERCTL_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    # Fetch fresh data
    local result
    if playerctl_is_playing; then
        result=$(playerctl_get_track_info)
    else
        result="Not Playing"
    fi

    # Update cache and output result
    cache_set "$PLAYERCTL_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
