#!/usr/bin/env bash
# =============================================================================
# Plugin: wifi
# Description: Display WiFi network name and signal strength
# Dependencies: None (uses native OS commands)
# =============================================================================
#
# Configuration options:
#   @powerkit_plugin_wifi_icon                 - Default icon (default: 󰤨)
#   @powerkit_plugin_wifi_icon_disconnected    - Icon when disconnected (default: 󰤭)
#   @powerkit_plugin_wifi_accent_color         - Default accent color
#   @powerkit_plugin_wifi_accent_color_icon    - Default icon accent color
#   @powerkit_plugin_wifi_show_ssid            - Show network name (default: true)
#   @powerkit_plugin_wifi_show_ip              - Show IP address instead of SSID (default: false)
#   @powerkit_plugin_wifi_show_signal          - Show signal strength (default: false)
#   @powerkit_plugin_wifi_cache_ttl            - Cache time in seconds (default: 10)
#
# Signal strength icons (when show_signal is true):
#   󰤯 - No signal (0-20%)
#   󰤟 - Weak (21-40%)
#   󰤢 - Fair (41-60%)
#   󰤥 - Good (61-80%)
#   󰤨 - Excellent (81-100%)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "wifi"

# =============================================================================
# WiFi Detection Functions
# =============================================================================

# Get WiFi info on macOS using ipconfig (requires verbose mode for SSID)
# To enable: sudo ipconfig setverbose 1
# Returns: "SSID:signal_percent" or empty if disconnected
get_wifi_macos_ipconfig() {
    local ssid
    ssid=$(ipconfig getsummary en0 2>/dev/null | awk '/ SSID :/{print $3}')
    
    # Check if we got a real SSID (not redacted)
    if [[ -n "$ssid" ]] && [[ "$ssid" != "<redacted>" ]] && [[ "$ssid" != *"redacted"* ]]; then
        # Connected with real SSID - get signal if possible
        local signal=75
        printf '%s:%d' "$ssid" "$signal"
        return 0
    fi
    
    return 1
}

# Get WiFi info on macOS using system_profiler
# Returns: "SSID:signal_percent" or empty if disconnected
get_wifi_macos_system_profiler() {
    # Use single awk call to parse system_profiler output more efficiently
    local wifi_data
    wifi_data=$(system_profiler SPAirPortDataType 2>/dev/null | awk '
        /Status: Connected/ {connected = 1}
        /Current Network Information:/ {if (connected) getline; gsub(/^[[:space:]]+|:$/, ""); ssid = $0}
        /RSSI:/ {if (connected) {gsub(/[^-0-9]/, ""); rssi = $0}}
        END {if (connected && ssid) print ssid ":" rssi; else exit 1}
    ')
    
    [[ -z "$wifi_data" ]] && return 1
    
    local ssid signal rssi
    ssid="${wifi_data%%:*}"
    rssi="${wifi_data##*:}"
    
    # macOS Sequoia+ redacts SSID for privacy - show "WiFi" as fallback
    if [[ -z "$ssid" ]] || [[ "$ssid" == "<redacted>" ]] || [[ "$ssid" == *"redacted"* ]]; then
        ssid="WiFi"
    fi
    
    # Get signal from RSSI if available
    local signal rssi
    rssi=$(echo "$info" | awk -F': ' '/RSSI/{print $2}' | tr -d ' ' | head -1)
    
    if [[ -n "$rssi" ]] && [[ "$rssi" =~ ^-?[0-9]+$ ]]; then
        signal=$(( (rssi + 100) * 100 / 70 ))
        (( signal > 100 )) && signal=100
        (( signal < 0 )) && signal=0
    else
        signal=75  # Default if can't get signal
    fi
    
    printf '%s:%d' "$ssid" "$signal"
}

# Get WiFi info on macOS using airport (legacy, macOS < 14)
# Returns: "SSID:signal_percent" or empty if disconnected
get_wifi_macos_airport() {
    local airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    
    [[ -x "$airport" ]] || return 1
    
    local info
    info=$("$airport" -I 2>/dev/null)
    
    [[ -z "$info" ]] && return 1
    
    # Check if connected
    if echo "$info" | grep -qE "AirPort: Off|state: init"; then
        return 1
    fi
    
    local ssid signal
    ssid=$(echo "$info" | awk -F': ' '/ SSID:/ {print $2}')
    signal=$(echo "$info" | awk -F': ' '/agrCtlRSSI:/ {print $2}')
    
    [[ -z "$ssid" ]] && return 1
    
    # Convert RSSI to percentage (typical range: -100 to -30)
    local signal_percent=0
    if [[ -n "$signal" ]]; then
        signal_percent=$(( (signal + 100) * 100 / 70 ))
        (( signal_percent > 100 )) && signal_percent=100
        (( signal_percent < 0 )) && signal_percent=0
    fi
    
    printf '%s:%d' "$ssid" "$signal_percent"
}

# Get WiFi info on macOS using networksetup (fallback)
get_wifi_macos_networksetup() {
    command -v networksetup &>/dev/null || return 1
    
    # Find WiFi interface
    local wifi_interface
    wifi_interface=$(networksetup -listallhardwareports 2>/dev/null | \
        awk '/Wi-Fi|AirPort/{getline; print $2}')
    
    [[ -z "$wifi_interface" ]] && wifi_interface="en0"
    
    local output
    output=$(networksetup -getairportnetwork "$wifi_interface" 2>/dev/null)
    
    # Check if connected
    if echo "$output" | grep -q "not associated"; then
        return 1
    fi
    
    local ssid
    ssid=${output#Current Wi-Fi Network: }
    
    [[ -z "$ssid" ]] && return 1
    
    # networksetup doesn't provide signal strength
    printf '%s:75' "$ssid"
}

# Main function to get WiFi info on macOS
# Try methods in order: ipconfig (if verbose enabled), system_profiler, airport (legacy), networksetup
get_wifi_macos() {
    get_wifi_macos_ipconfig || get_wifi_macos_system_profiler || get_wifi_macos_airport || get_wifi_macos_networksetup
}

# Get WiFi info on Linux using nmcli (optimized)
get_wifi_linux_nmcli() {
    command -v nmcli &>/dev/null || return 1
    
    # Single nmcli call with awk parsing for better performance
    nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | awk -F: '
        /^yes:/ && $2 != "" {
            gsub(/"/, "", $2)  # Remove quotes from SSID
            printf "%s:%d\n", $2, ($3 ? $3 : 0)
            exit 0
        }
        END {exit 1}
    '
}

# Get WiFi info on Linux using iwconfig
get_wifi_linux_iwconfig() {
    command -v iwconfig &>/dev/null || return 1
    
    local info interface ssid signal
    
    # Find wireless interface
    interface=$(iwconfig 2>&1 | grep -o "^[a-zA-Z0-9]*" | head -1)
    [[ -z "$interface" ]] && return 1
    
    info=$(iwconfig "$interface" 2>/dev/null)
    
    # Check if connected
    echo "$info" | grep -q "ESSID:off/any" && return 1
    
    ssid=$(echo "$info" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
    [[ -z "$ssid" ]] && return 1
    
    # Get signal quality (format: "Quality=XX/70" or "Signal level=-XX dBm")
    local quality
    quality=$(echo "$info" | grep -o 'Quality=[0-9]*/[0-9]*' | cut -d'=' -f2)
    
    if [[ -n "$quality" ]]; then
        local current max
        current=$(echo "$quality" | cut -d'/' -f1)
        max=$(echo "$quality" | cut -d'/' -f2)
        signal=$(( current * 100 / max ))
    else
        # Try to get from signal level dBm
        local level
        level=$(echo "$info" | grep -o 'Signal level=-[0-9]*' | cut -d'=' -f2)
        if [[ -n "$level" ]]; then
            signal=$(( (level + 100) * 100 / 70 ))
            (( signal > 100 )) && signal=100
            (( signal < 0 )) && signal=0
        fi
    fi
    
    printf '%s:%d' "$ssid" "${signal:-0}"
}

# Get WiFi info on Linux using iw
get_wifi_linux_iw() {
    command -v iw &>/dev/null || return 1
    
    local interface ssid signal
    
    # Find wireless interface
    interface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
    [[ -z "$interface" ]] && return 1
    
    # Get connection info
    local info
    info=$(iw dev "$interface" link 2>/dev/null)
    
    echo "$info" | grep -q "Not connected" && return 1
    
    ssid=$(echo "$info" | awk -F': ' '/SSID:/{print $2}')
    [[ -z "$ssid" ]] && return 1
    
    # Get signal in dBm
    local level
    level=$(echo "$info" | awk '/signal:/{print $2}')
    
    if [[ -n "$level" ]]; then
        signal=$(( (level + 100) * 100 / 70 ))
        (( signal > 100 )) && signal=100
        (( signal < 0 )) && signal=0
    fi
    
    printf '%s:%d' "$ssid" "${signal:-0}"
}

# Main function to get WiFi info
get_wifi_info() {
    if is_macos; then
        get_wifi_macos
    elif is_linux; then
        # Try multiple methods on Linux
        get_wifi_linux_nmcli || get_wifi_linux_iw || get_wifi_linux_iwconfig
    fi
}

# Get IP address for WiFi interface
get_wifi_ip() {
    local ip=""
    
    if is_macos; then
        # Try en0 (default WiFi interface on macOS)
        ip=$(ipconfig getifaddr en0 2>/dev/null)
        
        # Fallback: try to find WiFi interface dynamically
        if [[ -z "$ip" ]]; then
            local wifi_interface
            wifi_interface=$(networksetup -listallhardwareports 2>/dev/null | \
                awk '/Wi-Fi|AirPort/{getline; print $2}')
            [[ -n "$wifi_interface" ]] && ip=$(ipconfig getifaddr "$wifi_interface" 2>/dev/null)
        fi
    elif is_linux; then
        # Try common wireless interface names
        local interfaces=("wlan0" "wlp0s20f3" "wlp2s0" "wlp3s0")
        
        # First try to find the actual wireless interface
        if command -v iw &>/dev/null; then
            local detected
            detected=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
            [[ -n "$detected" ]] && interfaces=("$detected" "${interfaces[@]}")
        fi
        
        for iface in "${interfaces[@]}"; do
            ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet /{print $2}' | cut -d'/' -f1)
            [[ -n "$ip" ]] && break
        done
        
        # Fallback: use hostname
        [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    printf '%s' "$ip"
}

# Check if WiFi is available
wifi_is_available() {
    local info
    info=$(get_wifi_info)
    [[ -n "$info" ]]
}

# Get signal strength icon based on percentage
get_signal_icon() {
    local signal="$1"
    
    if (( signal <= 20 )); then
        printf '󰤯'
    elif (( signal <= 40 )); then
        printf '󰤟'
    elif (( signal <= 60 )); then
        printf '󰤢'
    elif (( signal <= 80 )); then
        printf '󰤥'
    else
        printf '󰤨'
    fi
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
    
    # Check if disconnected (content is passed as lowercase from renderer)
    if [[ -z "$content" ]] || [[ "$content" == "n/a" ]]; then
        icon=$(get_cached_option "@powerkit_plugin_wifi_icon_disconnected" "$POWERKIT_PLUGIN_WIFI_ICON_DISCONNECTED")
        accent=$(get_cached_option "@powerkit_plugin_wifi_disconnected_accent_color" "$POWERKIT_PLUGIN_WIFI_DISCONNECTED_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_wifi_disconnected_accent_color_icon" "$POWERKIT_PLUGIN_WIFI_DISCONNECTED_ACCENT_COLOR_ICON")
    else
        # WiFi is connected - set default colors
        accent=$(get_cached_option "@powerkit_plugin_wifi_accent_color" "$POWERKIT_PLUGIN_WIFI_ACCENT_COLOR")
        accent_icon=$(get_cached_option "@powerkit_plugin_wifi_accent_color_icon" "$POWERKIT_PLUGIN_WIFI_ACCENT_COLOR_ICON")
        
        # Extract signal from content if present
        local show_signal
        show_signal=$(get_cached_option "@powerkit_plugin_wifi_show_signal" "$POWERKIT_PLUGIN_WIFI_SHOW_SIGNAL")
        
        if [[ "$show_signal" == "true" ]]; then
            # Content format: "SSID (XX%)" - extract percentage
            local signal
            signal=$(echo "$content" | grep -oE '[0-9]+%' | tr -d '%')
            if [[ -n "$signal" ]]; then
                icon=$(get_signal_icon "$signal")
            fi
        fi
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
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local wifi_info
    wifi_info=$(get_wifi_info)
    
    if [[ -z "$wifi_info" ]]; then
        # Not connected or WiFi not available
        local result="N/A"
        cache_set "$CACHE_KEY" "$result"
        printf '%s' "$result"
        return 0
    fi
    
    # Parse info (format: "SSID:signal_percent")
    local ssid signal
    ssid="${wifi_info%%:*}"
    signal="${wifi_info##*:}"
    
    # Build output based on settings
    local show_ssid show_ip show_signal result display_text
    show_ssid=$(get_tmux_option "@powerkit_plugin_wifi_show_ssid" "$POWERKIT_PLUGIN_WIFI_SHOW_SSID")
    show_ip=$(get_tmux_option "@powerkit_plugin_wifi_show_ip" "$POWERKIT_PLUGIN_WIFI_SHOW_IP")
    show_signal=$(get_tmux_option "@powerkit_plugin_wifi_show_signal" "$POWERKIT_PLUGIN_WIFI_SHOW_SIGNAL")
    
    # Determine what to display: IP takes priority over SSID
    if [[ "$show_ip" == "true" ]]; then
        display_text=$(get_wifi_ip)
        [[ -z "$display_text" ]] && display_text="$ssid"  # Fallback to SSID
    elif [[ "$show_ssid" == "true" ]]; then
        display_text="$ssid"
    else
        display_text="$ssid"
    fi
    
    if [[ "$show_signal" == "true" ]] && [[ -n "$display_text" ]]; then
        result="${display_text} (${signal}%)"
    else
        result="$display_text"
    fi
    
    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
