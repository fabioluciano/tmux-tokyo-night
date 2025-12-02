#!/usr/bin/env bash
# =============================================================================
# Plugin: uptime
# Description: Display system uptime
# Dependencies: None
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
plugin_uptime_icon=$(get_tmux_option "@theme_plugin_uptime_icon" "$PLUGIN_UPTIME_ICON")
# shellcheck disable=SC2034
plugin_uptime_accent_color=$(get_tmux_option "@theme_plugin_uptime_accent_color" "$PLUGIN_UPTIME_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_uptime_accent_color_icon=$(get_tmux_option "@theme_plugin_uptime_accent_color_icon" "$PLUGIN_UPTIME_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 60 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_uptime_cache_ttl" "$PLUGIN_UPTIME_CACHE_TTL")
CACHE_KEY="uptime"

export plugin_uptime_icon plugin_uptime_accent_color plugin_uptime_accent_color_icon

# =============================================================================
# Uptime Functions
# =============================================================================

format_uptime() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    
    if [[ $days -gt 0 ]]; then
        printf '%dd %dh' "$days" "$hours"
    elif [[ $hours -gt 0 ]]; then
        printf '%dh %dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

get_uptime_linux() {
    # Single awk call to read and parse /proc/uptime (faster)
    awk '{printf "%d", $1}' /proc/uptime 2>/dev/null | {
        read -r uptime_seconds
        format_uptime "$uptime_seconds"
    }
}

get_uptime_macos() {
    # More efficient: get boot time and current time in awk
    sysctl -n kern.boottime 2>/dev/null | awk -v current="$(date +%s)" '
        {gsub(/[{},:]/," "); print current - $4}' | {
        read -r uptime_seconds
        format_uptime "$uptime_seconds"
    }
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'static'
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local result
    # Use cached OS detection from utils.sh
    if is_linux; then
        result=$(get_uptime_linux)
    elif is_macos; then
        result=$(get_uptime_macos)
    else
        result="N/A"
    fi

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
