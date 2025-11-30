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
#   @theme_plugin_battery_icon                 - Default icon (default: 󰁹)
#   @theme_plugin_battery_icon_charging        - Icon when charging (default: 󰂄)
#   @theme_plugin_battery_icon_low             - Icon when battery is low (default: 󰂃)
#   @theme_plugin_battery_accent_color         - Default accent color
#   @theme_plugin_battery_accent_color_icon    - Default icon accent color
#   @theme_plugin_battery_display_mode         - "percentage" or "time" (default: percentage)
#   @theme_plugin_battery_cache_ttl            - Cache time in seconds (default: 30)
#
# Threshold/Display options:
#   @theme_plugin_battery_display_threshold    - Show only when condition is met
#   @theme_plugin_battery_display_condition    - Condition: le, lt, ge, gt, eq, always
#   @theme_plugin_battery_low_threshold        - Threshold for low state (default: 30)
#   @theme_plugin_battery_low_accent_color     - Color when low (default: red)
#   @theme_plugin_battery_low_accent_color_icon - Icon color when low (default: red1)
#
# Example configurations:
#   # Show battery only when below 50%
#   set -g @theme_plugin_battery_display_threshold "50"
#   set -g @theme_plugin_battery_display_condition "le"
#
#   # Change colors when battery is below 20%
#   set -g @theme_plugin_battery_low_threshold "20"
#   set -g @theme_plugin_battery_low_accent_color "red"
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
plugin_battery_icon=$(get_tmux_option "@theme_plugin_battery_icon" "$PLUGIN_BATTERY_ICON")
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
        status_file=$(find /sys/class/power_supply/*/status 2>/dev/null | head -n1)
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
    local percentage
    percentage=$(battery_get_percentage)
    [[ -n "$percentage" ]]
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

# This function is called by render_plugins.sh to get display decisions
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
    local display_condition display_threshold
    display_condition=$(get_tmux_option "@theme_plugin_battery_display_condition" "always")
    display_threshold=$(get_tmux_option "@theme_plugin_battery_display_threshold" "")
    
    if [[ "$display_condition" != "always" ]] && [[ -n "$display_threshold" ]]; then
        if ! evaluate_condition "$value" "$display_condition" "$display_threshold"; then
            show="0"
        fi
    fi
    
    # Check if charging - use charging icon, skip low threshold colors
    if battery_is_charging; then
        icon=$(get_tmux_option "@theme_plugin_battery_icon_charging" "$PLUGIN_BATTERY_ICON_CHARGING")
    else
        # Check low threshold for color and icon changes
        local low_threshold
        low_threshold=$(get_tmux_option "@theme_plugin_battery_low_threshold" "$PLUGIN_BATTERY_LOW_THRESHOLD")
        
        if [[ -n "$value" ]] && [[ "$value" -le "$low_threshold" ]]; then
            accent=$(get_tmux_option "@theme_plugin_battery_low_accent_color" "$PLUGIN_BATTERY_LOW_ACCENT_COLOR")
            accent_icon=$(get_tmux_option "@theme_plugin_battery_low_accent_color_icon" "$PLUGIN_BATTERY_LOW_ACCENT_COLOR_ICON")
            icon=$(get_tmux_option "@theme_plugin_battery_icon_low" "$PLUGIN_BATTERY_ICON_LOW")
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
    display_mode=$(get_tmux_option "@theme_plugin_battery_display_mode" "$PLUGIN_BATTERY_DISPLAY_MODE")

    local cached_value
    if cached_value=$(cache_get "$BATTERY_CACHE_KEY" "$BATTERY_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    local percentage
    percentage=$(battery_get_percentage)
    
    local result
    result=$(battery_format_output "$percentage" "$display_mode")

    cache_set "$BATTERY_CACHE_KEY" "$result"
    printf '%s' "$result"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
