#!/usr/bin/env bash
# =============================================================================
# Plugin: datetime
# Description: Display current date and time with advanced formatting options
# Dependencies: None (uses tmux's built-in strftime)
# =============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=src/defaults.sh
. "$ROOT_DIR/../defaults.sh"
# shellcheck source=src/utils.sh
. "$ROOT_DIR/../utils.sh"

# =============================================================================
# Predefined Formats
# =============================================================================

declare -A DATETIME_FORMATS=(
    ["time"]="%H:%M"
    ["time-seconds"]="%H:%M:%S"
    ["time-12h"]="%I:%M %p"
    ["time-12h-seconds"]="%I:%M:%S %p"
    ["date"]="%d/%m"
    ["date-us"]="%m/%d"
    ["date-full"]="%d/%m/%Y"
    ["date-full-us"]="%m/%d/%Y"
    ["date-iso"]="%Y-%m-%d"
    ["datetime"]="%d/%m %H:%M"
    ["datetime-us"]="%m/%d %I:%M %p"
    ["weekday"]="%a %H:%M"
    ["weekday-full"]="%A %H:%M"
    ["full"]="%a, %d %b %H:%M"
    ["full-date"]="%a, %d %b %Y"
    ["iso"]="%Y-%m-%dT%H:%M:%S"
)

# =============================================================================
# Plugin Configuration
# =============================================================================

# shellcheck disable=SC2034
plugin_datetime_icon=$(get_tmux_option "@theme_plugin_datetime_icon" "$PLUGIN_DATETIME_ICON")
# shellcheck disable=SC2034
plugin_datetime_accent_color=$(get_tmux_option "@theme_plugin_datetime_accent_color" "$PLUGIN_DATETIME_ACCENT_COLOR")
# shellcheck disable=SC2034
plugin_datetime_accent_color_icon=$(get_tmux_option "@theme_plugin_datetime_accent_color_icon" "$PLUGIN_DATETIME_ACCENT_COLOR_ICON")

# Format configuration
plugin_datetime_format=$(get_tmux_option "@theme_plugin_datetime_format" "$PLUGIN_DATETIME_FORMAT")
plugin_datetime_timezone=$(get_tmux_option "@theme_plugin_datetime_timezone" "$PLUGIN_DATETIME_TIMEZONE")
plugin_datetime_show_week=$(get_tmux_option "@theme_plugin_datetime_show_week" "$PLUGIN_DATETIME_SHOW_WEEK")
plugin_datetime_separator=$(get_tmux_option "@theme_plugin_datetime_separator" "$PLUGIN_DATETIME_SEPARATOR")

export plugin_datetime_icon plugin_datetime_accent_color plugin_datetime_accent_color_icon

# =============================================================================
# Helper Functions
# =============================================================================

# Resolve predefined format or return custom format
datetime_resolve_format() {
    local format="$1"
    
    # Check if it's a predefined format
    if [[ -n "${DATETIME_FORMATS[$format]:-}" ]]; then
        printf '%s' "${DATETIME_FORMATS[$format]}"
    else
        # Return as-is (custom strftime format)
        printf '%s' "$format"
    fi
}

# Get timezone time using date command (for secondary timezone)
datetime_get_timezone_time() {
    local tz="$1"
    local format="$2"
    
    if command -v date &>/dev/null; then
        TZ="$tz" date +"$format" 2>/dev/null
    fi
}

# Get week number
datetime_get_week_number() {
    date +"W%V" 2>/dev/null || date +"W%W" 2>/dev/null
}

# =============================================================================
# Plugin Interface Implementation
# =============================================================================

# Function to inform the plugin type to the renderer
plugin_get_type() {
    printf 'datetime'
}

# =============================================================================
# Main Plugin Logic
# =============================================================================

load_plugin() {
    local output=""
    local resolved_format
    local separator="${plugin_datetime_separator:- }"
    
    # Resolve the format (predefined or custom)
    resolved_format=$(datetime_resolve_format "$plugin_datetime_format")
    
    # Start with main format
    output="$resolved_format"
    
    # Add week number if enabled
    if [[ "$plugin_datetime_show_week" == "true" ]]; then
        local week_num
        week_num=$(datetime_get_week_number)
        output="${week_num}${separator}${output}"
    fi
    
    # Add secondary timezone if configured
    if [[ -n "$plugin_datetime_timezone" ]]; then
        local tz_time
        # We need to output this as literal text, not strftime
        # So we use a shell command substitution that tmux will execute
        tz_time="#(TZ='$plugin_datetime_timezone' date +'%H:%M')"
        output="${output}${separator}${tz_time}"
    fi
    
    printf '%s' "$output"
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_plugin
fi
