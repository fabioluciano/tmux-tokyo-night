#!/usr/bin/env bash
# =============================================================================
# Plugin: uptime
# Description: Display system uptime
# Dependencies: None
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "uptime"

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
    local uptime_seconds
    uptime_seconds=$(sysctl -n kern.boottime 2>/dev/null | awk -v current="$(date +%s)" '
        /sec =/ {gsub(/[{},:=]/," "); for(i=1;i<=NF;i++) if($i=="sec") {print current - $(i+1); exit}}')
    format_uptime "$uptime_seconds"
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
