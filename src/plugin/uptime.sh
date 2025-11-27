#!/usr/bin/env bash
# =============================================================================
# Plugin: uptime
# Description: Display system uptime
# Dependencies: None
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
plugin_uptime_icon=$(get_tmux_option "@theme_plugin_uptime_icon" "󰔟 ")
# shellcheck disable=SC2034
plugin_uptime_accent_color=$(get_tmux_option "@theme_plugin_uptime_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_uptime_accent_color_icon=$(get_tmux_option "@theme_plugin_uptime_accent_color_icon" "blue0")

# Cache TTL in seconds (uptime updates every 60 seconds)
CACHE_TTL=60
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
    local uptime_seconds
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    format_uptime "$uptime_seconds"
}

get_uptime_macos() {
    local boot_time current_time uptime_seconds
    boot_time=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')
    current_time=$(date +%s)
    uptime_seconds=$((current_time - boot_time))
    format_uptime "$uptime_seconds"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        echo -n "$cached_value"
        return
    fi

    local result
    case "$(uname -s)" in
        Linux*)
            result=$(get_uptime_linux)
            ;;
        Darwin*)
            result=$(get_uptime_macos)
            ;;
        *)
            result="N/A"
            ;;
    esac

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

load_plugin
