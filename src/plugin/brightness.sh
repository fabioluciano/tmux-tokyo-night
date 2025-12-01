#!/usr/bin/env bash
# =============================================================================
# Plugin: brightness
# Description: Display screen brightness level (Linux only)
# Platform: Linux only - macOS is not supported
# Dependencies: 
#   - Linux: brightnessctl, light, or xbacklight
# =============================================================================
#
# Configuration options:
#   @theme_plugin_brightness_icon              - Default icon (default: 󰃞)
#   @theme_plugin_brightness_accent_color      - Default accent color
#   @theme_plugin_brightness_accent_color_icon - Default icon accent color
#   @theme_plugin_brightness_cache_ttl         - Cache time in seconds (default: 2)
#
# Display threshold options:
#   @theme_plugin_brightness_display_condition - Condition: le, lt, ge, gt, eq, ne, always
#   @theme_plugin_brightness_display_threshold - Show only when condition is met
#
# Dynamic icon options:
#   @theme_plugin_brightness_icon_low          - Icon when brightness < 30% (default: 󰃚)
#   @theme_plugin_brightness_icon_medium       - Icon when brightness < 70% (default: 󰃝)
#   @theme_plugin_brightness_icon_high         - Icon when brightness >= 70% (default: 󰃞)
#
# Linux Setup (one of):
#   - Ubuntu/Debian: sudo apt install brightnessctl
#   - Arch: sudo pacman -S brightnessctl
#   - Alternative: sudo apt install light
#   - X11: sudo apt install xbacklight
#
# Example configurations:
#   # Show brightness only when below 50%
#   set -g @theme_plugin_brightness_display_threshold "50"
#   set -g @theme_plugin_brightness_display_condition "le"
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
plugin_brightness_icon=$(get_tmux_option "@theme_plugin_brightness_icon" "$PLUGIN_BRIGHTNESS_ICON")
# shellcheck disable=SC2034
plugin_brightness_accent_color=$(get_tmux_option "@theme_plugin_brightness_accent_color" "$PLUGIN_BRIGHTNESS_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_brightness_accent_color_icon=$(get_tmux_option "@theme_plugin_brightness_accent_color_icon" "$PLUGIN_BRIGHTNESS_ACCENT_COLOR_ICON")

# Cache settings
BRIGHTNESS_CACHE_TTL=$(get_tmux_option "@theme_plugin_brightness_cache_ttl" "$PLUGIN_BRIGHTNESS_CACHE_TTL")
BRIGHTNESS_CACHE_KEY="brightness"

# =============================================================================
# Brightness Detection Functions
# =============================================================================

# Get brightness on Linux
get_brightness_linux() {
    # Method 1: Read directly from sysfs (fastest - no external commands)
    local backlight_dir="/sys/class/backlight"
    if [[ -d "$backlight_dir" ]]; then
        # Try to find any backlight device
        for device in "$backlight_dir"/*; do
            if [[ -f "$device/brightness" ]] && [[ -f "$device/max_brightness" ]]; then
                local current max
                current=$(<"$device/brightness" 2>/dev/null)
                max=$(<"$device/max_brightness" 2>/dev/null)
                if [[ -n "$current" ]] && [[ -n "$max" ]] && [[ "$max" -gt 0 ]]; then
                    awk -v curr="$current" -v m="$max" 'BEGIN {printf "%d", (curr/m)*100}'
                    return 0
                fi
            fi
        done
    fi
    
    # Method 2: Try using brightnessctl (if sysfs not available)
    local max
    max=$(brightnessctl max 2>/dev/null)
    if brightnessctl get 2>/dev/null | awk -v max="$max" 'BEGIN {if(max>0) printf "%d", ($0/max)*100}'; then
        return 0
    fi
    
    # Method 3: Try using light
    if light -G 2>/dev/null | awk '{printf "%d", $1}'; then
        return 0
    fi
    
    # Method 4: Try using xbacklight
    if xbacklight -get 2>/dev/null | awk '{printf "%d", $1}'; then
        return 0
    fi
    
    return 1
}

# Main function to get brightness (Linux only)
get_brightness() {
    # Only Linux is supported
    if ! is_linux; then
        return 1
    fi
    
    get_brightness_linux
}

# Check if brightness is available
brightness_is_available() {
    local test_brightness
    test_brightness=$(get_brightness)
    [[ -n "$test_brightness" ]] && [[ "$test_brightness" =~ ^[0-9]+$ ]]
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
    
    # Extract numeric value from content
    local value
    value=$(extract_numeric "$content")
    
    # Check display condition
    local display_condition display_threshold
    display_condition=$(get_cached_option "@theme_plugin_brightness_display_condition" "always")
    display_threshold=$(get_cached_option "@theme_plugin_brightness_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        if ! evaluate_condition "$value" "$display_condition" "$display_threshold"; then
            show="0"
        fi
    fi
    
    # Dynamic icon based on brightness level
    if [[ -n "$value" ]]; then
        local icon_low icon_medium icon_high
        icon_low=$(get_cached_option "@theme_plugin_brightness_icon_low" "$PLUGIN_BRIGHTNESS_ICON_LOW")
        icon_medium=$(get_cached_option "@theme_plugin_brightness_icon_medium" "$PLUGIN_BRIGHTNESS_ICON_MEDIUM")
        icon_high=$(get_cached_option "@theme_plugin_brightness_icon_high" "$PLUGIN_BRIGHTNESS_ICON_HIGH")
        
        if [[ "$value" -lt 30 ]]; then
            icon="$icon_low"
        elif [[ "$value" -lt 70 ]]; then
            icon="$icon_medium"
        else
            icon="$icon_high"
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check if brightness is available
    if ! brightness_is_available; then
        return 0
    fi
    
    # Check cache first
    local cached_value
    if cached_value=$(cache_get "$BRIGHTNESS_CACHE_KEY" "$BRIGHTNESS_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi
    
    # Get brightness level
    local brightness
    brightness=$(get_brightness)
    
    if [[ -z "$brightness" ]] || ! [[ "$brightness" =~ ^[0-9]+$ ]]; then
        return 0
    fi
    
    # Format output
    local result="${brightness}%"
    
    cache_set "$BRIGHTNESS_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
