#!/usr/bin/env bash
# =============================================================================
# Plugin: battery
# Description: Display battery percentage and charging status
# Dependencies: pmset (macOS), acpi/upower (Linux), or termux-battery-status
# =============================================================================
# Battery querying code adapted from https://github.com/tmux-plugins/tmux-battery
# Copyright (C) 2014 Bruno Sutic - MIT License

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"
# shellcheck source=src/cache.sh
. "$ROOT_DIR/../cache.sh"

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_battery_icon=$(get_tmux_option "@theme_plugin_battery_icon" "󰁹 ")
# shellcheck disable=SC2034
plugin_battery_accent_color=$(get_tmux_option "@theme_plugin_battery_accent_color" "blue7")
# shellcheck disable=SC2034
plugin_battery_accent_color_icon=$(get_tmux_option "@theme_plugin_battery_accent_color_icon" "blue0")

# Cache TTL in seconds (default: 30 seconds)
BATTERY_CACHE_TTL=$(get_tmux_option "@theme_plugin_battery_cache_ttl" "30")
BATTERY_CACHE_KEY="battery"

export plugin_battery_icon plugin_battery_accent_color plugin_battery_accent_color_icon

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
# Get battery charging status
# Returns: "charging", "charged", "discharging", or empty
# -----------------------------------------------------------------------------
battery_get_status() {
    if is_wsl; then
        local battery_file
        battery_file=$(find /sys/class/power_supply/*/status 2>/dev/null | head -n1)
        [[ -n "$battery_file" ]] && awk '{print tolower($0)}' "$battery_file"
    elif command_exists "pmset"; then
        pmset -g batt | awk -F '; *' 'NR==2 { print $2 }'
    elif command_exists "acpi"; then
        acpi -b | awk '{gsub(/,/, ""); print tolower($3); exit}'
    elif command_exists "upower"; then
        local battery
        battery=$(upower -e 2>/dev/null | grep -E 'battery|DisplayDevice' | tail -n1)
        [[ -n "$battery" ]] && upower -i "$battery" | awk '/state/ {print $2}'
    elif command_exists "termux-battery-status"; then
        termux-battery-status 2>/dev/null | jq -r '.status' 2>/dev/null | awk '{print tolower($1)}'
    elif command_exists "apm"; then
        local status
        status=$(apm -a 2>/dev/null)
        case "$status" in
            0) echo "discharging" ;;
            1) echo "charging" ;;
        esac
    fi
}

# -----------------------------------------------------------------------------
# Get battery percentage
# Returns: Numeric percentage value (e.g., "85")
# -----------------------------------------------------------------------------
battery_get_percentage() {
    local percentage=""
    
    if is_wsl; then
        local battery_file
        battery_file=$(find /sys/class/power_supply/*/capacity 2>/dev/null | head -n1)
        [[ -n "$battery_file" ]] && percentage=$(cat "$battery_file" 2>/dev/null)
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
    
    [[ -n "$percentage" ]] && echo -n "$percentage"
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
# Format battery output
# Returns: Formatted string with percentage and optional charging indicator
# -----------------------------------------------------------------------------
battery_format_output() {
    local percentage="$1"
    local status="$2"
    
    echo -n "${percentage}%"
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    # Check if battery is available - fail silently if not
    if ! battery_is_available; then
        return 0
    fi

    # Try to get from cache first
    local cached_value
    if cached_value=$(cache_get "$BATTERY_CACHE_KEY" "$BATTERY_CACHE_TTL"); then
        printf '%s' "$cached_value"
        return 0
    fi

    # Fetch fresh data
    local percentage status result
    percentage=$(battery_get_percentage)
    status=$(battery_get_status)
    result=$(battery_format_output "$percentage" "$status")

    # Update cache and output result
    cache_set "$BATTERY_CACHE_KEY" "$result"
    echo -n "$result"
}

load_plugin
