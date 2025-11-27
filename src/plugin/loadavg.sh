#!/usr/bin/env bash
# =============================================================================
# Plugin: loadavg
# Description: Display system load average
# Dependencies: None (uses /proc/loadavg on Linux, sysctl on macOS)
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
plugin_loadavg_icon=$(get_tmux_option "@theme_plugin_loadavg_icon" "󰊚 ")
# shellcheck disable=SC2034
plugin_loadavg_accent_color=$(get_tmux_option "@theme_plugin_loadavg_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_loadavg_accent_color_icon=$(get_tmux_option "@theme_plugin_loadavg_accent_color_icon" "blue0")

# Display format: "1" (1min), "5" (5min), "15" (15min), or "all" (1/5/15)
plugin_loadavg_format=$(get_tmux_option "@theme_plugin_loadavg_format" "1")

# Cache TTL in seconds (default: 5 seconds)
CACHE_TTL=$(get_tmux_option "@theme_plugin_loadavg_cache_ttl" "5")
CACHE_KEY="loadavg"

export plugin_loadavg_icon plugin_loadavg_accent_color plugin_loadavg_accent_color_icon

# =============================================================================
# Load Average Functions
# =============================================================================

# Get load average on Linux
get_loadavg_linux() {
    local load1 load5 load15
    
    if [[ -f /proc/loadavg ]]; then
        read -r load1 load5 load15 _ < /proc/loadavg
    else
        # Fallback to uptime command
        local uptime_output
        uptime_output=$(uptime 2>/dev/null)
        load1=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | awk -F', ' '{print $1}' | tr -d ' ')
        load5=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | awk -F', ' '{print $2}' | tr -d ' ')
        load15=$(echo "$uptime_output" | awk -F'load average:' '{print $2}' | awk -F', ' '{print $3}' | tr -d ' ')
    fi
    
    format_loadavg "$load1" "$load5" "$load15"
}

# Get load average on macOS
get_loadavg_macos() {
    local load1 load5 load15
    local loadavg_output
    
    # Use sysctl for faster access (use full path to avoid aliases)
    loadavg_output=$(/usr/sbin/sysctl -n vm.loadavg 2>/dev/null)
    
    if [[ -n "$loadavg_output" ]]; then
        # Output format: { 1.23 1.45 1.67 }
        # Remove braces and parse
        loadavg_output="${loadavg_output//[\{\}]/}"
        read -r load1 load5 load15 _ <<< "$loadavg_output"
    fi
    
    # Fallback to uptime if sysctl failed
    if [[ -z "$load1" ]]; then
        local uptime_output
        uptime_output=$(command uptime 2>/dev/null)
        # macOS uses "load averages:" (plural)
        load1=$(echo "$uptime_output" | sed 's/.*load averages*: *//' | awk '{print $1}')
        load5=$(echo "$uptime_output" | sed 's/.*load averages*: *//' | awk '{print $2}')
        load15=$(echo "$uptime_output" | sed 's/.*load averages*: *//' | awk '{print $3}')
    fi
    
    format_loadavg "$load1" "$load5" "$load15"
}

# Format output based on user preference
format_loadavg() {
    local load1="$1"
    local load5="$2"
    local load15="$3"
    
    # Ensure we have valid values
    [[ -z "$load1" ]] && load1="0"
    [[ -z "$load5" ]] && load5="0"
    [[ -z "$load15" ]] && load15="0"
    
    case "$plugin_loadavg_format" in
        1)
            printf '%s' "$load1"
            ;;
        5)
            printf '%s' "$load5"
            ;;
        15)
            printf '%s' "$load15"
            ;;
        all)
            printf '%s %s %s' "$load1" "$load5" "$load15"
            ;;
        *)
            printf '%s' "$load1"
            ;;
    esac
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
    # Use OS detection - check _CACHED_OS directly as fallback
    case "${_CACHED_OS:-$(uname -s)}" in
        Linux*)
            result=$(get_loadavg_linux)
            ;;
        Darwin*)
            result=$(get_loadavg_macos)
            ;;
        *)
            result="N/A"
            ;;
    esac

    # Update cache
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
