#!/usr/bin/env bash
# =============================================================================
# Plugin: battery
# Description: Display battery percentage or time remaining with dynamic colors
# Dependencies: pmset (macOS), acpi/upower (Linux), or termux-battery-status
# =============================================================================
# Battery querying code adapted from https://github.com/tmux-plugins/tmux-battery
# Copyright (C) 2014 Bruno Sutic - MIT License
#
# This plugin integrates with the threshold system (threshold_plugin.sh) for:
#   - Conditional display (e.g., only show when battery <= 50%)
#   - Dynamic icon and colors when battery is low
#
# Configuration options:
#   @theme_plugin_battery_icon                 - Default icon (default: 󰁹)
#   @theme_plugin_battery_icon_charging        - Icon when charging (default: 󰂄)
#   @theme_plugin_battery_icon_low             - Icon when battery is low (default: 󰂃)
#   @theme_plugin_battery_display_mode         - Display mode: "percentage" or "time" (default: percentage)
#                                                 percentage: Shows "85%"
#                                                 time: Shows time remaining like "2:30" or "4:15"
#   @theme_plugin_battery_low_threshold        - Threshold for low state (default: 30)
#   @theme_plugin_battery_low_accent_color     - Color when low (default: red)
#   @theme_plugin_battery_low_accent_color_icon - Icon color when low (default: red1)
#   @theme_plugin_battery_display_threshold    - Show only when <= this value
#   @theme_plugin_battery_display_condition    - Condition: le, lt, ge, gt, eq, always
#   @theme_plugin_battery_cache_ttl            - Cache time in seconds (default: 30)
#
# For 3-level thresholds (critical/warning/normal), use:
#   @theme_plugin_battery_threshold_mode       - Set to "descending"
#   @theme_plugin_battery_critical_threshold   - Critical level (default: 10)
#   @theme_plugin_battery_warning_threshold    - Warning level (default: 30)
#   @theme_plugin_battery_critical_color       - Color for critical level
#   @theme_plugin_battery_warning_color        - Color for warning level
#   @theme_plugin_battery_normal_color         - Color for normal level
#
# Example configurations in tmux.conf:
#   # Show time remaining instead of percentage
#   set -g @theme_plugin_battery_display_mode "time"
#
#   # Show battery only when below 50%
#   set -g @theme_plugin_battery_display_threshold "50"
#   set -g @theme_plugin_battery_display_condition "le"
#
#   # Change low battery threshold to 20%
#   set -g @theme_plugin_battery_low_threshold "20"
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

# Default icon (can be overridden by theme.sh or user config)
# shellcheck disable=SC2034
plugin_battery_icon=$(get_tmux_option "@theme_plugin_battery_icon" "$PLUGIN_BATTERY_ICON")

# Default colors
# shellcheck disable=SC2034
plugin_battery_accent_color=$(get_tmux_option "@theme_plugin_battery_accent_color" "$PLUGIN_BATTERY_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_battery_accent_color_icon=$(get_tmux_option "@theme_plugin_battery_accent_color_icon" "$PLUGIN_BATTERY_ACCENT_COLOR_ICON")

# Cache TTL in seconds (default: 30 seconds)
BATTERY_CACHE_TTL=$(get_tmux_option "@theme_plugin_battery_cache_ttl" "$PLUGIN_BATTERY_CACHE_TTL")
BATTERY_CACHE_KEY="battery"

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

# -----------------------------------------------------------------------------
# Get battery percentage
# Returns: Numeric percentage value (e.g., "85")
# -----------------------------------------------------------------------------
battery_get_percentage() {
    local percentage=""
    
    if is_wsl; then
        local battery_file
        battery_file=$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -n1)
        [[ -n "$battery_file" ]] && percentage=$(\cat "$battery_file" 2>/dev/null)
    elif command_exists "pmset"; then
        percentage=$(pmset -g batt 2>/dev/null | grep -o "[0-9]\{1,3\}%" | tr -d '%')
    elif command_exists "acpi"; then
        percentage=$(acpi -b 2>/dev/null | grep -m 1 -Eo "[0-9]+%" | tr -d '%')
    elif command_exists "upower"; then
        local battery
        battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
        if [[ -n "$battery" ]]; then
            percentage=$(upower -i "$battery" 2>/dev/null | awk '/percentage:/ {gsub(/%/, ""); print $2}')
            # Fallback to energy calculation
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

# -----------------------------------------------------------------------------
# Check if battery is charging (or connected to AC power)
# Returns: 0 if on AC power, 1 otherwise
# -----------------------------------------------------------------------------
battery_is_charging() {
    if is_wsl; then
        local status_file
        status_file=$(find /sys/class/power_supply/*/status 2>/dev/null | head -n1)
        [[ -n "$status_file" ]] && grep -qi "^charging$" "$status_file" 2>/dev/null && return 0
    elif command_exists "pmset"; then
        # Return 0 if on AC Power (regardless of charging state)
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

# -----------------------------------------------------------------------------
# Check if battery is available
# Returns: 0 if battery detected, 1 otherwise
# -----------------------------------------------------------------------------
battery_is_available() {
    local percentage
    percentage=$(battery_get_percentage)
    [[ -n "$percentage" ]]
}

# -----------------------------------------------------------------------------
# Get time remaining (charging or discharging)
# Returns: Time string like "1:30" or "2:45" or "calculating" or empty
# -----------------------------------------------------------------------------
battery_get_time_remaining() {
    local time_remaining=""
    
    if is_wsl; then
        # WSL doesn't typically provide time remaining
        time_remaining=""
    elif command_exists "pmset"; then
        # macOS: extract time from pmset output
        # Format: "2:30 remaining" or "1:45 until charged" or "(no estimate)"
        local pmset_output
        pmset_output=$(pmset -g batt 2>/dev/null)
        if echo "$pmset_output" | grep -q "(no estimate)"; then
            time_remaining="..."
        else
            time_remaining=$(echo "$pmset_output" | grep -oE '[0-9]+:[0-9]+' | head -1)
        fi
    elif command_exists "acpi"; then
        # Linux with acpi: "Battery 0: Discharging, 45%, 01:30:00 remaining"
        time_remaining=$(acpi -b 2>/dev/null | grep -oE '[0-9]+:[0-9]+:[0-9]+' | head -1 | cut -d: -f1-2)
    elif command_exists "upower"; then
        local battery
        battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
        if [[ -n "$battery" ]]; then
            # Try "time to empty" or "time to full"
            local seconds
            seconds=$(upower -i "$battery" 2>/dev/null | grep -E "time to (empty|full)" | awk '{print $4}')
            local unit
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

# -----------------------------------------------------------------------------
# Format battery output based on display mode
# Returns: Formatted string with percentage or time
# -----------------------------------------------------------------------------
battery_format_output() {
    local percentage="$1"
    local display_mode="$2"
    
    if [[ "$display_mode" == "time" ]]; then
        local time_remaining
        time_remaining=$(battery_get_time_remaining)
        if [[ -n "$time_remaining" ]]; then
            printf '%s' "$time_remaining"
        else
            # Fallback to percentage if time not available
            printf '%s%%' "$percentage"
        fi
    else
        printf '%s%%' "$percentage"
    fi
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check if battery is available - fail silently if not
    if ! battery_is_available; then
        return 0
    fi

    # Get display mode from tmux config
    local display_mode
    display_mode=$(get_tmux_option "@theme_plugin_battery_display_mode" "$PLUGIN_BATTERY_DISPLAY_MODE")

    # Try to get formatted output from cache
    local cached_value
    if cached_value=$(cache_get "$BATTERY_CACHE_KEY" "$BATTERY_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    # Get battery percentage
    local percentage
    percentage=$(battery_get_percentage)
    
    # Check charging status and set generic flags for threshold_plugin.sh
    if battery_is_charging; then
        # Tell threshold_plugin to skip low_threshold coloring
        cache_set "battery_skip_low_threshold" "1"
        # Override icon to charging icon
        local icon_charging
        icon_charging=$(get_tmux_option "@theme_plugin_battery_icon_charging" "$PLUGIN_BATTERY_ICON_CHARGING")
        cache_set "battery_icon_override" "$icon_charging"
    else
        cache_set "battery_skip_low_threshold" "0"
        # Clear icon override so threshold can use low icon if needed
        cache_set "battery_icon_override" ""
    fi

    # Format based on display mode
    local result
    result=$(battery_format_output "$percentage" "$display_mode")

    # Update cache and output result
    cache_set "$BATTERY_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
