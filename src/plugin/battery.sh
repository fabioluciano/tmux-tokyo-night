#!/usr/bin/env bash
# =============================================================================
# Plugin: battery
# Description: Display battery percentage or time remaining with dynamic colors
# Dependencies: pmset (macOS), acpi/upower (Linux), or termux-battery-status
# =============================================================================
# Battery querying code adapted from https://github.com/tmux-plugins/tmux-battery
# Copyright (C) 2014 Bruno Sutic - MIT License
#
# Configuration options:
#   @powerkit_plugin_battery_icon                 - Default icon (default: 󰁹)
#   @powerkit_plugin_battery_icon_charging        - Icon when charging (default: 󰂄)
#   @powerkit_plugin_battery_icon_low             - Icon when battery is low (default: 󰂃)
#   @powerkit_plugin_battery_accent_color         - Default accent color
#   @powerkit_plugin_battery_accent_color_icon    - Default icon accent color
#   @powerkit_plugin_battery_display_mode         - "percentage" or "time" (default: percentage)
#   @powerkit_plugin_battery_cache_ttl            - Cache time in seconds (default: 30)
#
# Threshold/Display options:
#   @powerkit_plugin_battery_display_threshold    - Show only when condition is met
#   @powerkit_plugin_battery_display_condition    - Condition: le, lt, ge, gt, eq, always
#   @powerkit_plugin_battery_low_threshold        - Threshold for low state (default: 30)
#   @powerkit_plugin_battery_low_accent_color     - Color when low (default: red)
#   @powerkit_plugin_battery_low_accent_color_icon - Icon color when low (default: red1)
#
# Example configurations:
#   # Show battery only when below 50%
#   set -g @powerkit_plugin_battery_display_threshold "50"
#   set -g @powerkit_plugin_battery_display_condition "le"
#
#   # Change colors when battery is below 20%
#   set -g @powerkit_plugin_battery_low_threshold "20"
#   set -g @powerkit_plugin_battery_low_accent_color "red"
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/plugin_bootstrap.sh
. "$ROOT_DIR/../plugin_bootstrap.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# Initialize cache (DRY - sets CACHE_KEY and CACHE_TTL automatically)
plugin_init "battery"

# =============================================================================
# Platform Detection
# =============================================================================

is_wsl() {
    [[ -f /proc/version ]] && grep -qiE "microsoft|wsl" /proc/version 2>/dev/null
}

command_exists() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# Battery Detection Functions
# =============================================================================

battery_get_percentage() {
    local percentage=""
    
    if is_wsl; then
        local battery_file
        battery_file=$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -n1)
        [[ -n "$battery_file" ]] && percentage=$(<"$battery_file" 2>/dev/null)
    elif is_macos && command_exists "pmset"; then
        percentage=$(pmset -g batt 2>/dev/null | awk '/[0-9]+%/ {gsub(/[%;]/, "", $3); print $3; exit}')
    elif is_linux && command_exists "acpi"; then
        percentage=$(acpi -b 2>/dev/null | awk -F'[,%]' '/Battery/ {gsub(/ /, "", $2); print $2; exit}')
    elif is_linux && command_exists "upower"; then
        local battery
        battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
        if [[ -n "$battery" ]]; then
            percentage=$(upower -i "$battery" 2>/dev/null | awk '/percentage:/ {gsub(/%/, ""); print $2}')
            if [[ -z "$percentage" ]]; then
                local energy energy_full
                energy=$(upower -i "$battery" | awk '/energy:/ {print $2}')
                energy_full=$(upower -i "$battery" | awk '/energy-full:/ {print $2}')
                if [[ -n "$energy" && -n "$energy_full" ]]; then
                    percentage=$(awk "BEGIN {printf \"%d\", ($energy/$energy_full)*100}")
                fi
            fi
        fi
    elif command_exists "termux-battery-status"; then
        percentage=$(termux-battery-status 2>/dev/null | jq -r '.percentage' 2>/dev/null)
    elif command_exists "apm"; then
        percentage=$(apm -l 2>/dev/null | tr -d '%')
    fi
    
    [[ -n "$percentage" ]] && printf '%s' "$percentage"
}

battery_is_charging() {
    if is_wsl; then
        local status_file
        status_file=$(command find /sys/class/power_supply/*/status 2>/dev/null | head -n1)
        [[ -n "$status_file" ]] && grep -qi "^charging$" "$status_file" 2>/dev/null && return 0
    elif command_exists "pmset"; then
        pmset -g batt 2>/dev/null | grep -q "AC Power" && return 0
        return 1
    elif command_exists "acpi"; then
        acpi -b 2>/dev/null | grep -qiE "^Battery.*: Charging" && return 0
    elif command_exists "upower"; then
        local battery
        battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
        [[ -n "$battery" ]] && upower -i "$battery" 2>/dev/null | grep -qiE "state:\s*charging" && return 0
    elif command_exists "termux-battery-status"; then
        termux-battery-status 2>/dev/null | jq -r '.status' 2>/dev/null | grep -qi "^charging$" && return 0
    fi
    return 1
}

battery_is_available() {
    # Check if we're in WSL
    if is_wsl; then
        local battery_file
        battery_file=$(command find /sys/class/power_supply/*/capacity 2>/dev/null | head -n1)
        [[ -n "$battery_file" ]] && return 0
        return 1
    fi
    
    # Check macOS with pmset
    if command_exists "pmset"; then
        pmset -g batt 2>/dev/null | grep -q "InternalBattery" && return 0
        return 1
    fi
    
    # Check Linux with acpi
    if command_exists "acpi"; then
        acpi -b 2>/dev/null | grep -q "Battery" && return 0
        return 1
    fi
    
    # Check Linux with upower - improved detection
    if command_exists "upower"; then
        local batteries
        batteries=$(upower -e 2>/dev/null | grep -v DisplayDevice | grep -E 'BAT|battery')
        if [[ -n "$batteries" ]]; then
            # Check if any battery has valid information
            while IFS= read -r battery; do
                if upower -i "$battery" 2>/dev/null | grep -q "power supply.*yes"; then
                    return 0
                fi
            done <<< "$batteries"
        fi
        
        # Also check DisplayDevice but ensure it's a real battery
        local display_device
        display_device=$(upower -e 2>/dev/null | grep DisplayDevice)
        if [[ -n "$display_device" ]]; then
            local upower_info
            upower_info=$(upower -i "$display_device" 2>/dev/null)
            # Check if it has power supply and is not missing
            if echo "$upower_info" | grep -q "power supply.*yes" && \
               ! echo "$upower_info" | grep -q "battery-missing"; then
                return 0
            fi
        fi
        return 1
    fi
    
    # Check Termux
    if command_exists "termux-battery-status"; then
        termux-battery-status 2>/dev/null >/dev/null && return 0
        return 1
    fi
    
    # Check BSD systems
    if command_exists "apm"; then
        apm -l 2>/dev/null >/dev/null && return 0
        return 1
    fi
    
    # No battery detection method available or no battery found
    return 1
}

battery_get_time_remaining() {
    local time_remaining=""
    
    if is_wsl; then
        time_remaining=""
    elif command_exists "pmset"; then
        local pmset_output
        pmset_output=$(pmset -g batt 2>/dev/null)
        if echo "$pmset_output" | grep -q "(no estimate)"; then
            time_remaining="..."
        else
            time_remaining=$(echo "$pmset_output" | grep -oE '[0-9]+:[0-9]+' | head -1)
        fi
    elif command_exists "acpi"; then
        time_remaining=$(acpi -b 2>/dev/null | grep -oE '[0-9]+:[0-9]+:[0-9]+' | head -1 | cut -d: -f1-2)
    elif command_exists "upower"; then
        local battery
        battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
        if [[ -n "$battery" ]]; then
            local seconds unit
            seconds=$(upower -i "$battery" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $4}')
            unit=$(upower -i "$battery" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $5}')
            if [[ -n "$seconds" ]]; then
                case "$unit" in
                    hours) time_remaining="${seconds}h" ;;
                    minutes) time_remaining="${seconds}m" ;;
                    *) time_remaining="$seconds" ;;
                esac
            fi
        fi
    fi
    
    printf '%s' "$time_remaining"
}

battery_format_output() {
    local percentage="$1"
    local display_mode="$2"
    
    # Remove any existing % symbol from percentage
    percentage="${percentage%\%}"
    
    if [[ "$display_mode" == "time" ]]; then
        local time_remaining
        time_remaining=$(battery_get_time_remaining)
        if [[ -n "$time_remaining" ]]; then
            printf '%s' "$time_remaining"
        else
            printf '%s%%' "$percentage"
        fi
    else
        printf '%s%%' "$percentage"
    fi
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'conditional'
}

# This function is called by plugin_helpers.sh to get display decisions
# Output format: "show:accent:accent_icon:icon"
plugin_get_display_info() {
    local content="$1"
    local show="1"
    local accent=""
    local accent_icon=""
    local icon=""
    
    # Extract numeric value from content
    local value
    value=$(extract_numeric "$content")
    
    # Check display condition (hide based on threshold)
    # Use get_cached_option for performance in render loop
    local display_condition display_threshold
    display_condition=$(get_cached_option "@powerkit_plugin_battery_display_condition" "always")
    display_threshold=$(get_cached_option "@powerkit_plugin_battery_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        if ! evaluate_condition "$value" "$display_condition" "$display_threshold"; then
            show="0"
        fi
    fi
    
    # Default colors
    accent=$(get_cached_option "@powerkit_plugin_battery_accent_color" "$POWERKIT_PLUGIN_BATTERY_ACCENT_COLOR")
    accent_icon=$(get_cached_option "@powerkit_plugin_battery_accent_color_icon" "$POWERKIT_PLUGIN_BATTERY_ACCENT_COLOR_ICON")
    
    # Check if charging - use charging icon, skip low threshold colors
    if battery_is_charging; then
        icon=$(get_cached_option "@powerkit_plugin_battery_icon_charging" "$POWERKIT_PLUGIN_BATTERY_ICON_CHARGING")
    else
        # Check thresholds for color and icon changes (check low first, then warning)
        local low_threshold warning_threshold
        low_threshold=$(get_cached_option "@powerkit_plugin_battery_low_threshold" "$POWERKIT_PLUGIN_BATTERY_LOW_THRESHOLD")
        warning_threshold=$(get_cached_option "@powerkit_plugin_battery_warning_threshold" "$POWERKIT_PLUGIN_BATTERY_WARNING_THRESHOLD")
        
        if [[ -n "$value" ]] && [[ "$value" -le "$low_threshold" ]]; then
            # Critical low (30% or less) - red colors
            accent=$(get_cached_option "@powerkit_plugin_battery_low_accent_color" "$POWERKIT_PLUGIN_BATTERY_LOW_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_battery_low_accent_color_icon" "$POWERKIT_PLUGIN_BATTERY_LOW_ACCENT_COLOR_ICON")
            icon=$(get_cached_option "@powerkit_plugin_battery_icon_low" "$POWERKIT_PLUGIN_BATTERY_ICON_LOW")
        elif [[ -n "$value" ]] && [[ "$value" -le "$warning_threshold" ]]; then
            # Warning level (50% or less) - yellow colors
            accent=$(get_cached_option "@powerkit_plugin_battery_warning_accent_color" "$POWERKIT_PLUGIN_BATTERY_WARNING_ACCENT_COLOR")
            accent_icon=$(get_cached_option "@powerkit_plugin_battery_warning_accent_color_icon" "$POWERKIT_PLUGIN_BATTERY_WARNING_ACCENT_COLOR_ICON")
        fi
    fi
    
    build_display_info "$show" "$accent" "$accent_icon" "$icon"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    if ! battery_is_available; then
        return 0
    fi

    local display_mode
    display_mode=$(get_tmux_option "@powerkit_plugin_battery_display_mode" "$POWERKIT_PLUGIN_BATTERY_DISPLAY_MODE")

    local cached_value
    if cached_value=$(cache_get "$CACHE_KEY" "$CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    local percentage
    percentage=$(battery_get_percentage)
    
    local result
    result=$(battery_format_output "$percentage" "$display_mode")

    cache_set "$CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
