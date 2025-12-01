#!/usr/bin/env bash
# =============================================================================
# Plugin: bluetooth
# Description: Display Bluetooth status and connected devices
# Dependencies: None (uses native OS commands)
# =============================================================================
#
# Configuration options:
#   @theme_plugin_bluetooth_icon              - Icon when on (default: 󰂯)
#   @theme_plugin_bluetooth_icon_off          - Icon when off (default: 󰂲)
#   @theme_plugin_bluetooth_icon_connected    - Icon when device connected (default: 󰂱)
#   @theme_plugin_bluetooth_accent_color      - Default accent color
#   @theme_plugin_bluetooth_accent_color_icon - Default icon accent color
#   @theme_plugin_bluetooth_show_device       - Show connected device name (default: true)
#   @theme_plugin_bluetooth_show_battery      - Show battery level if available (default: true)
#   @theme_plugin_bluetooth_format            - Display format: first, count, all (default: all)
#   @theme_plugin_bluetooth_max_length        - Max device name length (default: 15)
#   @theme_plugin_bluetooth_cache_ttl         - Cache time in seconds (default: 10)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"
# shellcheck source=src/plugin_interface.sh
. "$ROOT_DIR/../plugin_interface.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_bluetooth_icon=$(get_tmux_option "@theme_plugin_bluetooth_icon" "$PLUGIN_BLUETOOTH_ICON")
# shellcheck disable=SC2034
plugin_bluetooth_accent_color=$(get_tmux_option "@theme_plugin_bluetooth_accent_color" "$PLUGIN_BLUETOOTH_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_bluetooth_accent_color_icon=$(get_tmux_option "@theme_plugin_bluetooth_accent_color_icon" "$PLUGIN_BLUETOOTH_ACCENT_COLOR_ICON")

# Cache settings
BLUETOOTH_CACHE_TTL=$(get_tmux_option "@theme_plugin_bluetooth_cache_ttl" "$PLUGIN_BLUETOOTH_CACHE_TTL")
BLUETOOTH_CACHE_KEY="bluetooth"

# =============================================================================
# Bluetooth Detection Functions
# =============================================================================

# Get Bluetooth status and connected devices on macOS
# Returns: "status:device1@battery1|device2@battery2|..." or "status:"
# Battery is included after @ if available, empty otherwise
get_bluetooth_macos() {
    # Try blueutil first (fastest, if available)
    if command -v blueutil &>/dev/null; then
        if [[ "$(blueutil -p)" == "0" ]]; then
            printf 'off:'
            return 0
        fi
        
        # Try to get battery info using blueutil --connected with -info flag
        # Note: This requires blueutil version that supports battery reporting
        local connected_devices=""
        local devices
        devices=$(blueutil --connected 2>/dev/null)
        
        if [[ -n "$devices" ]]; then
            while IFS= read -r line; do
                # Parse: address: 40-ed-98-1d-47-a8, connected (master, -53 dBm), name: "RETRO NANO", recent access date: 2024-11-30
                if [[ "$line" =~ name:\ \"([^\"]+)\" ]]; then
                    local device_name="${BASH_REMATCH[1]}"
                    local battery=""
                    
                    # Extract MAC address from the line
                    if [[ "$line" =~ address:\ ([0-9a-f-]+) ]]; then
                        local mac_addr="${BASH_REMATCH[1]}"
                        # Try to get battery info (may not be supported by all blueutil versions)
                        battery=$(blueutil --info "$mac_addr" 2>/dev/null | grep -i "battery" | grep -oE '[0-9]+%' | tr -d '%' | head -1)
                    fi
                    
                    if [[ -n "$connected_devices" ]]; then
                        connected_devices="${connected_devices}|"
                    fi
                    connected_devices="${connected_devices}${device_name}@${battery}"
                fi
            done <<< "$devices"
            
            if [[ -n "$connected_devices" ]]; then
                printf 'connected:%s' "$connected_devices"
                return 0
            fi
        fi
    fi
    
    # Use system_profiler to check status and connected devices
    if command -v system_profiler &>/dev/null; then
        local info
        info=$(system_profiler SPBluetoothDataType 2>/dev/null)
        
        [[ -z "$info" ]] && return 1
        
        # Check if Bluetooth is on by looking for "State: On"
        if ! echo "$info" | grep -q "State: On"; then
            printf 'off:'
            return 0
        fi
        
        # Look for a "Connected:" section that appears BEFORE "Not Connected:"
        # If only "Not Connected:" exists, no devices are connected
        local has_connected_section
        has_connected_section=$(echo "$info" | grep -E "^[[:space:]]+Connected:$" | head -1)
        
        if [[ -n "$has_connected_section" ]]; then
            # Extract ALL device names and their battery levels from the Connected section
            local connected_devices
            connected_devices=$(echo "$info" | awk '
                /^[[:space:]]+Connected:$/ { in_connected=1; next }
                /^[[:space:]]+Not Connected:$/ { exit }
                in_connected && /^[[:space:]]+[^[:space:]].*:$/ && !/Address:|Vendor|Product|Firmware|Minor|Serial|Case|Chipset|State|Discoverable|Transport|Supported|Battery|RSSI|Services/ { 
                    if (current_device != "") {
                        print current_device "@" battery
                    }
                    gsub(/^[[:space:]]+|:$/, "")
                    current_device = $0
                    battery = ""
                }
                in_connected && /Battery Level:/ {
                    # Get battery percentage - prefer main battery, then left/right average
                    match($0, /[0-9]+%/)
                    if (RSTART > 0) {
                        pct = substr($0, RSTART, RLENGTH-1)
                        if (battery == "" || !/Left|Right|Case/) {
                            battery = pct
                        }
                    }
                }
                END {
                    if (current_device != "") {
                        print current_device "@" battery
                    }
                }
            ' | tr '\n' '|' | sed 's/|$//')
            
            if [[ -n "$connected_devices" ]]; then
                printf 'connected:%s' "$connected_devices"
                return 0
            fi
        fi
        
        # No connected devices
        printf 'on:'
        return 0
    fi
    
    return 1
}

# Get Bluetooth status on Linux using bluetoothctl
get_bluetooth_linux_bluetoothctl() {
    command -v bluetoothctl &>/dev/null || return 1
    
    # Check if Bluetooth is powered on
    local powered
    powered=$(bluetoothctl show 2>/dev/null | grep -i "Powered:" | awk '{print $2}')
    
    if [[ "$powered" != "yes" ]]; then
        printf 'off:'
        return 0
    fi
    
    # Get connected devices
    local connected_device
    connected_device=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)
    
    # Fallback: check for any connected device
    if [[ -z "$connected_device" ]]; then
        local device_mac
        device_mac=$(bluetoothctl devices 2>/dev/null | head -1 | awk '{print $2}')
        if [[ -n "$device_mac" ]]; then
            local info
            info=$(bluetoothctl info "$device_mac" 2>/dev/null)
            if echo "$info" | grep -q "Connected: yes"; then
                connected_device=$(echo "$info" | grep "Name:" | cut -d' ' -f2-)
            fi
        fi
    fi
    
    if [[ -n "$connected_device" ]]; then
        printf 'connected:%s' "$connected_device"
    else
        printf 'on:'
    fi
}

# Get Bluetooth status on Linux using hcitool
get_bluetooth_linux_hcitool() {
    command -v hcitool &>/dev/null || return 1
    
    # Check if any Bluetooth adapter exists
    if ! hcitool dev 2>/dev/null | grep -q "hci"; then
        printf 'off:'
        return 0
    fi
    
    # Get connected devices
    local connected
    connected=$(hcitool con 2>/dev/null | grep -v "Connections:" | head -1 | awk '{print $3}')
    
    if [[ -n "$connected" ]]; then
        # Try to get device name
        local name
        name=$(hcitool name "$connected" 2>/dev/null)
        if [[ -n "$name" ]]; then
            printf 'connected:%s' "$name"
        else
            printf 'connected:Device'
        fi
    else
        printf 'on:'
    fi
}

# Main function to get Bluetooth info
get_bluetooth_info() {
    if is_macos; then
        get_bluetooth_macos
    elif is_linux; then
        get_bluetooth_linux_bluetoothctl || get_bluetooth_linux_hcitool
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
    
    # Parse status from content
    local status="${content%%:*}"
    
    case "$status" in
        off)
            icon=$(get_cached_option "@theme_plugin_bluetooth_icon_off" "$PLUGIN_BLUETOOTH_ICON_OFF")
            accent=$(get_cached_option "@theme_plugin_bluetooth_off_accent_color" "")
            accent_icon=$(get_cached_option "@theme_plugin_bluetooth_off_accent_color_icon" "")
            ;;
        connected)
            icon=$(get_cached_option "@theme_plugin_bluetooth_icon_connected" "$PLUGIN_BLUETOOTH_ICON_CONNECTED")
            accent=$(get_cached_option "@theme_plugin_bluetooth_connected_accent_color" "")
            accent_icon=$(get_cached_option "@theme_plugin_bluetooth_connected_accent_color_icon" "")
            ;;
        on)
            # Default icon, no color override
            ;;
    esac
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$BLUETOOTH_CACHE_KEY" "$BLUETOOTH_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    local bt_info
    bt_info=$(get_bluetooth_info)
    
    if [[ -z "$bt_info" ]]; then
        return 0
    fi
    
    # Parse info (format: "status:device1@battery1|device2@battery2|...")
    local status devices_str
    status="${bt_info%%:*}"
    devices_str="${bt_info#*:}"
    
    local result
    local show_device show_battery format max_length
    show_device=$(get_tmux_option "@theme_plugin_bluetooth_show_device" "$PLUGIN_BLUETOOTH_SHOW_DEVICE")
    show_battery=$(get_tmux_option "@theme_plugin_bluetooth_show_battery" "$PLUGIN_BLUETOOTH_SHOW_BATTERY")
    format=$(get_tmux_option "@theme_plugin_bluetooth_format" "$PLUGIN_BLUETOOTH_FORMAT")
    max_length=$(get_tmux_option "@theme_plugin_bluetooth_max_length" "$PLUGIN_BLUETOOTH_MAX_LENGTH")
    
    case "$status" in
        off)
            # Don't show anything when Bluetooth is off (conditional plugin)
            return 0
            ;;
        connected)
            if [[ "$show_device" == "true" ]] && [[ -n "$devices_str" ]]; then
                local display_text
                
                # Count devices (pipe-separated)
                local device_count
                device_count=$(echo "$devices_str" | tr '|' '\n' | wc -l | tr -d ' ')
                
                # Helper function to format device with battery
                format_device() {
                    local entry="$1"
                    local name="${entry%%@*}"
                    local battery="${entry#*@}"
                    
                    if [[ "$show_battery" == "true" ]] && [[ -n "$battery" ]] && [[ "$battery" != "$name" ]]; then
                        printf '%s (%s%%)' "$name" "$battery"
                    else
                        printf '%s' "$name"
                    fi
                }
                
                case "$format" in
                    count)
                        # Show count: "2 devices" or "1 device"
                        if [[ "$device_count" -eq 1 ]]; then
                            display_text="1 device"
                        else
                            display_text="${device_count} devices"
                        fi
                        ;;
                    all)
                        # Show all devices separated by comma
                        local formatted_devices=""
                        local IFS='|'
                        for entry in $devices_str; do
                            local formatted
                            formatted=$(format_device "$entry")
                            if [[ -n "$formatted_devices" ]]; then
                                formatted_devices="${formatted_devices}, ${formatted}"
                            else
                                formatted_devices="$formatted"
                            fi
                        done
                        display_text="$formatted_devices"
                        ;;
                    first|*)
                        # Show first device only (default)
                        local first_entry="${devices_str%%|*}"
                        display_text=$(format_device "$first_entry")
                        ;;
                esac
                
                # Truncate if too long
                if [[ ${#display_text} -gt $max_length ]]; then
                    display_text="${display_text:0:$((max_length-1))}…"
                fi
                result="connected:$display_text"
            else
                result="connected:Connected"
            fi
            ;;
        on)
            result="on:ON"
            ;;
    esac
    
    cache_set "$BLUETOOTH_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Output only the display part (after the colon)
    output=$(load_plugin)
    printf '%s' "${output#*:}"
fi
