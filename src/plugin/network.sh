#!/usr/bin/env bash
# =============================================================================
# Plugin: network
# Description: Display network upload/download speeds
# Dependencies: None
#
# PERFORMANCE: This plugin uses a delta-based approach instead of sleep.
# It stores the previous bytes count and timestamp, then calculates
# speed based on the time elapsed since last check. This is instant!
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "network"
CACHE_KEY_PREV="network_prev"

# Network interface (auto-detect if empty)
plugin_network_interface=$(get_tmux_option "@powerkit_plugin_network_interface" "$POWERKIT_PLUGIN_NETWORK_INTERFACE")

# =============================================================================
# Network Functions
# =============================================================================

# Convert bytes/sec to human readable speed
bytes_to_speed() {
    local bytes=$1
    
    # Handle negative or zero
    if [[ $bytes -le 0 ]]; then
        printf '0B'
        return
    fi
    
    if [[ $bytes -ge $POWERKIT_BYTE_GB ]]; then
        printf '%.1fG' "$(awk "BEGIN {printf \"%.1f\", $bytes / $POWERKIT_BYTE_GB}")"
    elif [[ $bytes -ge $POWERKIT_BYTE_MB ]]; then
        printf '%.1fM' "$(awk "BEGIN {printf \"%.1f\", $bytes / $POWERKIT_BYTE_MB}")"
    elif [[ $bytes -ge $POWERKIT_BYTE_KB ]]; then
        printf '%.0fK' "$(awk "BEGIN {printf \"%.0f\", $bytes / $POWERKIT_BYTE_KB}")"
    else
        printf '%dB' "$bytes"
    fi
}

# Get default interface with caching
get_default_interface() {
    local cache_key="network_interface"
    local cached_interface
    
    # Check cache first (interfaces don't change frequently)
    if cached_interface=$(cache_get "$cache_key" "$POWERKIT_TIMING_CACHE_INTERFACE"); then
        printf '%s' "$cached_interface"
        return
    fi
    
    local interface
    if is_linux; then
        interface=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
    elif is_macos; then
        interface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
    fi
    
    # Cache the result
    [[ -n "$interface" ]] && cache_set "$cache_key" "$interface"
    printf '%s' "$interface"
}

# Get current bytes (rx tx) on Linux
get_bytes_linux() {
    local interface="$1"
    local rx_file="/sys/class/net/${interface}/statistics/rx_bytes"
    local tx_file="/sys/class/net/${interface}/statistics/tx_bytes"
    
    if [[ -f "$rx_file" && -f "$tx_file" ]]; then
        printf '%s %s' "$(< "$rx_file")" "$(< "$tx_file")"
    fi
}

# Get current bytes (rx tx) on macOS
get_bytes_macos() {
    local interface="$1"
    netstat -I "$interface" -b 2>/dev/null | awk 'NR==2 {print $7, $10}'
}

# Get current timestamp in nanoseconds (or seconds with decimals)
get_timestamp() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS: use python for millisecond precision, fallback to seconds
        python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null || \
            printf '%s000' "$(date +%s)"
    else
        # Linux: nanoseconds available
        date +%s%3N 2>/dev/null || printf '%s000' "$(date +%s)"
    fi
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# Dynamic display info based on content
plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Hide plugin when no connectivity (empty or n/a)
    if [[ -z "$content" ]] || [[ "$content" == "n/a" ]]; then
        show="0"
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic - Delta-based (NO SLEEP!)
# =============================================================================

load_plugin() {
    # Check display cache first (the formatted output)
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return
    fi

    local interface="$plugin_network_interface"
    local os_type
    os_type="$(uname -s)"
    
    # Auto-detect interface with caching
    if [[ -z "$interface" ]]; then
        interface=$(get_default_interface)
    fi
    
    [[ -z "$interface" ]] && { printf 'N/A'; return; }
    
    # Get current bytes and timestamp
    local current_bytes current_time
    case "$os_type" in
        Linux*)  current_bytes=$(get_bytes_linux "$interface") ;;
        Darwin*) current_bytes=$(get_bytes_macos "$interface") ;;
        *)       printf 'N/A'; return ;;
    esac
    
    [[ -z "$current_bytes" ]] && { printf 'N/A'; return; }
    
    current_time=$(get_timestamp)
    
    # Read previous values from cache (format: "rx tx timestamp")
    local prev_data prev_rx prev_tx prev_time
    prev_data=$(cache_get "$CACHE_KEY_PREV" "$POWERKIT_TIMING_CACHE_LONG" 2>/dev/null || echo "")
    
    # Parse current values
    local current_rx current_tx
    read -r current_rx current_tx <<< "$current_bytes"
    
    # Save current values for next iteration
    cache_set "$CACHE_KEY_PREV" "$current_rx $current_tx $current_time"
    
    # If no previous data, don't show anything initially
    if [[ -z "$prev_data" ]]; then
        cache_set "$CACHE_KEY" ""
        return
    fi
    
    # Parse previous values
    read -r prev_rx prev_tx prev_time <<< "$prev_data"
    
    # Calculate time delta in seconds (timestamps are in milliseconds)
    local time_delta
    time_delta=$(awk "BEGIN {printf \"%.3f\", ($current_time - $prev_time) / 1000}")
    
    # Avoid division by zero or negative time
    if awk "BEGIN {exit !($time_delta <= $POWERKIT_TIMING_MIN_DELTA)}" 2>/dev/null; then
        time_delta="$POWERKIT_TIMING_FALLBACK"
    fi
    
    # Calculate bytes per second
    local rx_speed tx_speed
    rx_speed=$(awk "BEGIN {printf \"%.0f\", ($current_rx - $prev_rx) / $time_delta}")
    tx_speed=$(awk "BEGIN {printf \"%.0f\", ($current_tx - $prev_tx) / $time_delta}")
    
    # Handle counter reset (reboot, interface restart)
    [[ $rx_speed -lt 0 ]] && rx_speed=0
    [[ $tx_speed -lt 0 ]] && tx_speed=0
    
    # Get configurable threshold (default: 50KB/s total)
    local threshold
    threshold=$(get_tmux_option "@powerkit_plugin_network_threshold" "$POWERKIT_PLUGIN_NETWORK_THRESHOLD")
    
    # Only show if there's significant network activity above threshold
    # This excludes normal background traffic but shows actual usage
    local total_speed
    total_speed=$(awk "BEGIN {printf \"%.0f\", $rx_speed + $tx_speed}")
    if [[ $total_speed -le $threshold ]]; then
        # No significant network activity, don't display anything
        cache_set "$CACHE_KEY" ""
        return
    fi
    
    local result
    result="↓$(bytes_to_speed "$rx_speed") ↑$(bytes_to_speed "$tx_speed")"
    
    # Cache the formatted result
    cache_set "$CACHE_KEY" "$result"
    
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
