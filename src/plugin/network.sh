#!/usr/bin/env bash
# =============================================================================
# Plugin: network
# Description: Display network upload/download speeds
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
plugin_network_icon=$(get_tmux_option "@theme_plugin_network_icon" "󰛳 ")
# shellcheck disable=SC2034
plugin_network_accent_color=$(get_tmux_option "@theme_plugin_network_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_network_accent_color_icon=$(get_tmux_option "@theme_plugin_network_accent_color_icon" "blue0")

# Network interface (auto-detect if empty)
plugin_network_interface=$(get_tmux_option "@theme_plugin_network_interface" "")

# Cache TTL in seconds
CACHE_TTL=2
CACHE_KEY="network"

export plugin_network_icon plugin_network_accent_color plugin_network_accent_color_icon

# =============================================================================
# Network Functions
# =============================================================================

# Convert bytes to human readable
bytes_to_speed() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        printf '%.1fG' "$(echo "scale=1; $bytes / 1073741824" | bc 2>/dev/null || echo "0")"
    elif [[ $bytes -ge 1048576 ]]; then
        printf '%.1fM' "$(echo "scale=1; $bytes / 1048576" | bc 2>/dev/null || echo "0")"
    elif [[ $bytes -ge 1024 ]]; then
        printf '%.0fK' "$(echo "scale=0; $bytes / 1024" | bc 2>/dev/null || echo "0")"
    else
        printf '%dB' "$bytes"
    fi
}

# Get default interface on Linux
get_default_interface_linux() {
    ip route | grep default | head -1 | awk '{print $5}'
}

# Get default interface on macOS
get_default_interface_macos() {
    route -n get default 2>/dev/null | grep interface | awk '{print $2}'
}

# Get network stats on Linux
get_network_linux() {
    local interface="$1"
    local rx_file="/sys/class/net/${interface}/statistics/rx_bytes"
    local tx_file="/sys/class/net/${interface}/statistics/tx_bytes"
    
    if [[ ! -f "$rx_file" ]]; then
        printf 'N/A'
        return
    fi
    
    # Read current values
    local rx1 tx1 rx2 tx2
    rx1=$(cat "$rx_file")
    tx1=$(cat "$tx_file")
    
    sleep 1
    
    rx2=$(cat "$rx_file")
    tx2=$(cat "$tx_file")
    
    local rx_speed=$((rx2 - rx1))
    local tx_speed=$((tx2 - tx1))
    
    printf '↓%s ↑%s' "$(bytes_to_speed $rx_speed)" "$(bytes_to_speed $tx_speed)"
}

# Get network stats on macOS
get_network_macos() {
    local interface="$1"
    
    # Use netstat to get bytes
    local stats1 stats2
    stats1=$(netstat -I "$interface" -b 2>/dev/null | tail -1)
    
    if [[ -z "$stats1" ]]; then
        printf 'N/A'
        return
    fi
    
    local rx1 tx1
    rx1=$(echo "$stats1" | awk '{print $7}')
    tx1=$(echo "$stats1" | awk '{print $10}')
    
    sleep 1
    
    stats2=$(netstat -I "$interface" -b 2>/dev/null | tail -1)
    local rx2 tx2
    rx2=$(echo "$stats2" | awk '{print $7}')
    tx2=$(echo "$stats2" | awk '{print $10}')
    
    local rx_speed=$((rx2 - rx1))
    local tx_speed=$((tx2 - tx1))
    
    printf '↓%s ↑%s' "$(bytes_to_speed $rx_speed)" "$(bytes_to_speed $tx_speed)"
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

    local interface="$plugin_network_interface"
    local result
    
    case "$(uname -s)" in
        Linux*)
            [[ -z "$interface" ]] && interface=$(get_default_interface_linux)
            result=$(get_network_linux "$interface")
            ;;
        Darwin*)
            [[ -z "$interface" ]] && interface=$(get_default_interface_macos)
            result=$(get_network_macos "$interface")
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
